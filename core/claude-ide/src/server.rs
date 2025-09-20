use anyhow::{anyhow, Result};
use fastwebsockets::{upgrade, FragmentCollector, Frame, OpCode, WebSocketError};
use http_body_util::Empty;
use hyper::body::Bytes;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::Request;
use hyper_util::rt::TokioIo;
use serde_json::{self, json};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex, RwLock};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use crate::cli::{Response as CliResponse, StdinRequest};
use crate::lock_file::LockFileManager;
use crate::mcp::{parse_mcp_message, serialize_mcp_message, McpHandler, SelectionUpdate};

type Clients = Arc<RwLock<HashMap<String, mpsc::UnboundedSender<String>>>>;
type DiagnosticsCache = Arc<RwLock<serde_json::Value>>;

pub struct WebSocketServer {
    port_min: u16,
    port_max: u16,
    port: Option<u16>,
    auth_token: Option<String>,
    workspace_folder: Option<String>,
    lock_manager: LockFileManager,
    mcp_handler: McpHandler,
    clients: Clients,
    running: Arc<Mutex<bool>>,
    selection_broadcaster: Option<mpsc::UnboundedSender<SelectionUpdate>>,
    diagnostics_cache: DiagnosticsCache,
}

impl WebSocketServer {
    pub async fn new(port_min: u16, port_max: u16) -> Result<Self> {
        // Create selection broadcaster channel
        let (selection_tx, mut selection_rx) = mpsc::unbounded_channel::<SelectionUpdate>();

        let clients: Clients = Arc::new(RwLock::new(HashMap::new()));
        let clients_for_selection = clients.clone();

        // Spawn task to handle selection updates
        tokio::spawn(async move {
            while let Some(selection_update) = selection_rx.recv().await {
                info!("Broadcasting selection update for {}", selection_update.file_path);

                // Convert selection update to selection_changed notification
                let start_char = 0; // Default values, could be enhanced
                let end_char = selection_update.text.len() as u32;

                let selection_message = crate::mcp::McpMessage::new_notification(
                    "selection_changed".to_string(),
                    Some(serde_json::json!({
                        "text": selection_update.text,
                        "filePath": selection_update.file_path,
                        "fileUrl": format!("file://{}", selection_update.file_path),
                        "selection": {
                            "start": {
                                "line": selection_update.line_start.unwrap_or(0),
                                "character": start_char
                            },
                            "end": {
                                "line": selection_update.line_end.unwrap_or(0),
                                "character": end_char
                            },
                            "isEmpty": selection_update.text.is_empty()
                        }
                    }))
                );

                if let Ok(message_json) = serde_json::to_string(&selection_message) {
                    let clients_read = clients_for_selection.read().await;
                    let mut sent_count = 0;

                    for (client_id, sender) in clients_read.iter() {
                        if let Err(e) = sender.send(message_json.clone()) {
                            warn!("Failed to send selection update to client {}: {}", client_id, e);
                        } else {
                            sent_count += 1;
                        }
                    }

                    info!("Sent selection update to {} clients", sent_count);
                }
            }
        });

        // Initialize empty diagnostics cache
        let diagnostics_cache = Arc::new(RwLock::new(json!({})));

        Ok(Self {
            port_min,
            port_max,
            port: None,
            auth_token: None,
            workspace_folder: None,
            lock_manager: LockFileManager::new(),
            mcp_handler: McpHandler::new()
                .with_selection_broadcaster(selection_tx.clone())
                .with_diagnostics_cache(diagnostics_cache.clone()),
            clients,
            running: Arc::new(Mutex::new(false)),
            selection_broadcaster: Some(selection_tx),
            diagnostics_cache,
        })
    }

    pub fn set_workspace_folder(&mut self, workspace_folder: Option<String>) {
        self.workspace_folder = workspace_folder;
    }

    /// Find an available port in the range
    async fn find_available_port(&self) -> Result<u16> {
        for port in self.port_min..=self.port_max {
            if let Ok(listener) = TcpListener::bind(format!("127.0.0.1:{}", port)).await {
                drop(listener);
                return Ok(port);
            }
        }
        Err(anyhow!("No available ports in range {}-{}", self.port_min, self.port_max))
    }

    /// Start the WebSocket server
    pub async fn start(&mut self) -> Result<(u16, String)> {
        let port = self.find_available_port().await?;
        let auth_token = Uuid::new_v4().to_string();

        let listener = TcpListener::bind(format!("127.0.0.1:{}", port))
            .await
            .map_err(|e| anyhow!("Failed to bind to port {}: {}", port, e))?;

        self.port = Some(port);
        self.auth_token = Some(auth_token.clone());

        // Create lock file
        self.lock_manager.create_lock_file(port, &auth_token, self.workspace_folder.as_deref())?;

        *self.running.lock().await = true;

        info!("WebSocket server started on port {}", port);

        // Clone necessary data for the spawned task
        let clients = self.clients.clone();
        let mcp_handler = Arc::new(self.mcp_handler.clone());
        let auth_token_for_server = auth_token.clone();
        let running = self.running.clone();

        tokio::spawn(async move {
            Self::accept_connections(listener, clients, mcp_handler, auth_token_for_server, running).await;
        });

        Ok((port, auth_token))
    }

    async fn accept_connections(
        listener: TcpListener,
        clients: Clients,
        mcp_handler: Arc<McpHandler>,
        auth_token: String,
        running: Arc<Mutex<bool>>,
    ) {
        while *running.lock().await {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    debug!("New connection from {}", addr);

                    let clients = clients.clone();
                    let mcp_handler = mcp_handler.clone();
                    let auth_token = auth_token.clone();

                    tokio::spawn(async move {
                        if let Err(e) = Self::handle_connection(stream, addr, clients, mcp_handler, auth_token).await {
                            error!("Connection error: {}", e);
                        }
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }

    async fn handle_connection(
        stream: TcpStream,
        addr: SocketAddr,
        clients: Clients,
        mcp_handler: Arc<McpHandler>,
        auth_token: String,
    ) -> Result<()> {
        let io = TokioIo::new(stream);

        let service = service_fn(move |request| {
            Self::handle_request(
                request,
                clients.clone(),
                mcp_handler.clone(),
                auth_token.clone(),
            )
        });

        if let Err(err) = http1::Builder::new()
            .serve_connection(io, service)
            .with_upgrades()
            .await
        {
            error!("Connection from {} failed: {}", addr, err);
        }

        Ok(())
    }

    async fn handle_request(
        request: Request<hyper::body::Incoming>,
        clients: Clients,
        mcp_handler: Arc<McpHandler>,
        auth_token: String,
    ) -> Result<hyper::Response<Empty<Bytes>>, hyper::Error> {
        // ==== COMPREHENSIVE REQUEST LOGGING ====
        let method = request.method().to_string();
        let uri = request.uri().to_string();
        let version = format!("{:?}", request.version());

        info!("=== INCOMING REQUEST ===");
        info!("Method: {}", method);
        info!("URI: {}", uri);
        info!("Version: {}", version);

        // Log all headers
        info!("Headers:");
        for (name, value) in request.headers() {
            if let Ok(value_str) = value.to_str() {
                info!("  {}: {}", name, value_str);
            } else {
                info!("  {}: <binary data>", name);
            }
        }

        // Save detailed request to file
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let log_entry = format!(
            "=== REQUEST {} ===\n{} {} {}\nHeaders:\n{}\n\n",
            timestamp,
            method, uri, version,
            request.headers().iter()
                .map(|(k, v)| format!("  {}: {}", k, v.to_str().unwrap_or("<binary>")))
                .collect::<Vec<_>>()
                .join("\n")
        );

        if let Err(e) = std::fs::write("/tmp/claude_requests.log", log_entry) {
            warn!("Failed to write request log: {}", e);
        } else {
            info!("Request logged to /tmp/claude_requests.log");
        }

        // Check if this is a WebSocket upgrade request
        if fastwebsockets::upgrade::is_upgrade_request(&request) {
            // Validate authentication header
            if let Some(auth_header) = request.headers().get("x-claude-code-ide-authorization") {
                if let Ok(auth_value) = auth_header.to_str() {
                    if auth_value != auth_token {
                        warn!("Authentication failed for WebSocket upgrade");
                        return Ok(hyper::Response::builder()
                            .status(401)
                            .body(Empty::new())
                            .unwrap());
                    }
                } else {
                    warn!("Invalid authentication header format");
                    return Ok(hyper::Response::builder()
                        .status(400)
                        .body(Empty::new())
                        .unwrap());
                }
            } else {
                warn!("Missing authentication header");
                return Ok(hyper::Response::builder()
                    .status(401)
                    .body(Empty::new())
                    .unwrap());
            }

            debug!("WebSocket upgrade request authenticated");

            // Perform WebSocket upgrade with MCP subprotocol support
            let (mut response, websocket_fut) = upgrade::upgrade(request).unwrap();

            // Add MCP subprotocol to response headers
            response.headers_mut().insert(
                "sec-websocket-protocol",
                "mcp".parse().unwrap()
            );

            // Handle the WebSocket connection
            tokio::spawn(async move {
                if let Ok(websocket) = websocket_fut.await {
                    if let Err(e) = Self::handle_websocket(websocket, clients, mcp_handler).await {
                        error!("WebSocket error: {}", e);
                    }
                } else {
                    error!("WebSocket upgrade failed");
                }
            });

            Ok(response)
        } else {
            // Not a WebSocket request
            Ok(hyper::Response::builder()
                .status(404)
                .body(Empty::new())
                .unwrap())
        }
    }

    async fn handle_websocket(
        websocket: fastwebsockets::WebSocket<TokioIo<hyper::upgrade::Upgraded>>,
        clients: Clients,
        mcp_handler: Arc<McpHandler>,
    ) -> Result<(), WebSocketError> {
        let client_id = Uuid::new_v4().to_string();
        let (tx, mut rx) = mpsc::unbounded_channel::<String>();

        // Add client to the clients map
        {
            let mut clients_map = clients.write().await;
            clients_map.insert(client_id.clone(), tx.clone());
        }

        info!("WebSocket client connected: {} (ready to receive selections from Neovim)", client_id);

        let mut ws = FragmentCollector::new(websocket);

        loop {
            tokio::select! {
                // Handle incoming WebSocket messages
                frame_result = ws.read_frame() => {
                    match frame_result {
                        Ok(frame) => {
                            match frame.opcode {
                                OpCode::Text => {
                                    let text = String::from_utf8_lossy(&frame.payload);
                                    debug!("Received message: {}", text);

                                    // Parse and handle MCP message
                                    match parse_mcp_message(&text) {
                                        Ok(mcp_message) => {
                                            let is_notification = mcp_message.id.is_none();
                                            match mcp_handler.handle_message(mcp_message) {
                                                Ok(response) => {
                                                    // Only send response for requests (not notifications)
                                                    if !is_notification && response.method != Some("ignored".to_string()) {
                                                        match serialize_mcp_message(&response) {
                                                            Ok(response_text) => {
                                                                debug!("Sending response: {}", response_text);
                                                                let response_frame = Frame::text(fastwebsockets::Payload::Owned(response_text.into_bytes()));
                                                                if let Err(e) = ws.write_frame(response_frame).await {
                                                                    error!("Failed to send response: {}", e);
                                                                    break;
                                                                }
                                                            }
                                                            Err(e) => error!("Failed to serialize response: {}", e),
                                                        }
                                                    } else if is_notification {
                                                        debug!("Received notification, no response needed");
                                                    }
                                                }
                                                Err(e) => error!("Failed to handle MCP message: {}", e),
                                            }
                                        }
                                        Err(e) => error!("Failed to parse MCP message: {}", e),
                                    }
                                }
                                OpCode::Binary => {
                                    warn!("Received binary message, ignoring");
                                }
                                OpCode::Close => {
                                    info!("Client {} disconnected", client_id);
                                    break;
                                }
                                OpCode::Ping => {
                                    let pong_frame = Frame::pong(fastwebsockets::Payload::Owned(frame.payload.to_vec()));
                                    if let Err(e) = ws.write_frame(pong_frame).await {
                                        error!("Failed to send pong: {}", e);
                                        break;
                                    }
                                }
                                OpCode::Pong => {
                                    debug!("Received pong from client {}", client_id);
                                }
                                _ => {
                                    warn!("Received unsupported frame type: {:?}", frame.opcode);
                                }
                            }
                        }
                        Err(e) => {
                            error!("Error reading frame: {}", e);
                            break;
                        }
                    }
                }

                // Handle outgoing messages
                Some(message) = rx.recv() => {
                    let frame = Frame::text(fastwebsockets::Payload::Owned(message.into_bytes()));
                    if let Err(e) = ws.write_frame(frame).await {
                        error!("Failed to send message to client {}: {}", client_id, e);
                        break;
                    }
                }
            }
        }

        // Remove client from the clients map
        {
            let mut clients_map = clients.write().await;
            clients_map.remove(&client_id);
        }

        info!("WebSocket client {} disconnected", client_id);
        Ok(())
    }

    /// Stop the server
    pub async fn stop(&mut self) -> Result<()> {
        *self.running.lock().await = false;

        if let Some(port) = self.port {
            self.lock_manager.remove_lock_file(port)?;
        }

        info!("Server stopped");
        Ok(())
    }

    /// Get server status
    pub fn get_status(&self) -> CliResponse {
        if let (Some(port), Some(auth_token)) = (&self.port, &self.auth_token) {
            CliResponse {
                success: true,
                port: Some(*port),
                auth_token: Some(auth_token.clone()),
                error: None,
                connected: Some(!self.clients.blocking_read().is_empty()),
            }
        } else {
            CliResponse {
                success: false,
                port: None,
                auth_token: None,
                error: Some("Server not running".to_string()),
                connected: Some(false),
            }
        }
    }

    /// Run the server with stdin command handling
    pub async fn run(&mut self) -> Result<()> {
        // Handle stdin commands
        let stdin = tokio::io::stdin();
        let reader = BufReader::new(stdin);
        let mut lines = reader.lines();

        while let Ok(Some(line)) = lines.next_line().await {
            if line.trim().is_empty() {
                continue;
            }

            match self.handle_stdin_command(&line).await {
                Ok(response) => {
                    let response_json = serde_json::to_string(&response)?;
                    println!("{}", response_json);
                }
                Err(e) => {
                    let error_response = CliResponse {
                        success: false,
                        port: None,
                        auth_token: None,
                        error: Some(e.to_string()),
                        connected: None,
                    };
                    let response_json = serde_json::to_string(&error_response)?;
                    println!("{}", response_json);
                }
            }
        }

        self.stop().await?;
        Ok(())
    }

    async fn handle_stdin_command(&mut self, line: &str) -> Result<CliResponse> {
        let request: StdinRequest = serde_json::from_str(line)?;

        match request.method.as_str() {
            "start" => {
                if self.port.is_some() {
                    // Already running
                    Ok(self.get_status())
                } else {
                    let (port, auth_token) = self.start().await?;
                    Ok(CliResponse {
                        success: true,
                        port: Some(port),
                        auth_token: Some(auth_token),
                        error: None,
                        connected: Some(false),
                    })
                }
            }
            "stop" => {
                self.stop().await?;
                Ok(CliResponse {
                    success: true,
                    port: None,
                    auth_token: None,
                    error: None,
                    connected: None,
                })
            }
            "status" => Ok(self.get_status()),
            "send_selection" => {
                if let Some(params) = request.params {
                    let file_path = params.get("filePath")
                        .and_then(|v| v.as_str())
                        .unwrap_or("/Users/le/nerdtools/test.ts");
                    let text = params.get("text")
                        .and_then(|v| v.as_str())
                        .unwrap_or("console.log('Hello from Claude IDE');");
                    let start_line = params.get("startLine")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(0) as u32;
                    let start_char = params.get("startChar")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(0) as u32;
                    let end_line = params.get("endLine")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(0) as u32;
                    let end_char = params.get("endChar")
                        .and_then(|v| v.as_u64())
                        .unwrap_or(text.len() as u64) as u32;

                    self.send_selection_update(file_path, text, start_line, start_char, end_line, end_char).await?;

                    Ok(CliResponse {
                        success: true,
                        port: self.port,
                        auth_token: self.auth_token.clone(),
                        error: None,
                        connected: Some(!self.clients.read().await.is_empty()),
                    })
                } else {
                    // Send default test selection
                    self.send_selection_update(
                        "/Users/le/nerdtools/test.ts",
                        "console.log('Hello from Claude IDE');",
                        0, 0, 0, 36
                    ).await?;

                    Ok(CliResponse {
                        success: true,
                        port: self.port,
                        auth_token: self.auth_token.clone(),
                        error: None,
                        connected: Some(!self.clients.read().await.is_empty()),
                    })
                }
            }
            "send_message" => {
                // Handle send_message requests from Neovim WebSocket client
                if let Some(params) = request.params {
                    let method = params.get("method")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let message_params = params.get("params");

                    if method == "at_mentioned" {
                        // Create a fake MCP message for the handler
                        let mcp_message = crate::mcp::McpMessage::new_notification(
                            "at_mentioned".to_string(),
                            message_params.cloned(),
                        );

                        // Process through MCP handler (which will broadcast selection)
                        match self.mcp_handler.handle_message(mcp_message) {
                            Ok(_) => {
                                info!("Processed at_mentioned from Neovim");
                                Ok(CliResponse {
                                    success: true,
                                    port: self.port,
                                    auth_token: self.auth_token.clone(),
                                    error: None,
                                    connected: Some(!self.clients.read().await.is_empty()),
                                })
                            }
                            Err(e) => {
                                error!("Failed to process at_mentioned: {}", e);
                                Ok(CliResponse {
                                    success: false,
                                    port: self.port,
                                    auth_token: self.auth_token.clone(),
                                    error: Some(e.to_string()),
                                    connected: Some(!self.clients.read().await.is_empty()),
                                })
                            }
                        }
                    } else {
                        Ok(CliResponse {
                            success: true,
                            port: self.port,
                            auth_token: self.auth_token.clone(),
                            error: None,
                            connected: Some(!self.clients.read().await.is_empty()),
                        })
                    }
                } else {
                    Ok(CliResponse {
                        success: false,
                        port: self.port,
                        auth_token: self.auth_token.clone(),
                        error: Some("Missing params for send_message".to_string()),
                        connected: Some(!self.clients.read().await.is_empty()),
                    })
                }
            }
            "send_notification" => {
                // Handle send_notification requests from Neovim (no response expected)
                if let Some(params) = request.params {
                    let method = params.get("method")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let notification_params = params.get("params");

                    // Forward diagnostics updates to Claude Code
                    if method == "diagnostics_updated" {
                        if let Some(notification_params) = notification_params {
                            self.send_diagnostics_update(notification_params).await?;
                            info!("Forwarded diagnostics update to Claude Code");
                        }
                    }

                    // Always return success for notifications
                    Ok(CliResponse {
                        success: true,
                        port: self.port,
                        auth_token: self.auth_token.clone(),
                        error: None,
                        connected: Some(!self.clients.read().await.is_empty()),
                    })
                } else {
                    Ok(CliResponse {
                        success: false,
                        port: self.port,
                        auth_token: self.auth_token.clone(),
                        error: Some("Missing params for send_notification".to_string()),
                        connected: Some(!self.clients.read().await.is_empty()),
                    })
                }
            }
            _ => Err(anyhow!("Unknown method: {}", request.method)),
        }
    }

    /// Send a selection_changed notification to all connected clients
    pub async fn send_selection_update(&self, file_path: &str, selection_text: &str, start_line: u32, start_char: u32, end_line: u32, end_char: u32) -> Result<()> {
        use crate::mcp::McpMessage;
        use serde_json::json;

        let selection_message = McpMessage::new_notification(
            "selection_changed".to_string(),
            Some(json!({
                "text": selection_text,
                "filePath": file_path,
                "fileUrl": format!("file://{}", file_path),
                "selection": {
                    "start": { "line": start_line, "character": start_char },
                    "end": { "line": end_line, "character": end_char },
                    "isEmpty": selection_text.is_empty()
                }
            }))
        );

        let message_json = match serde_json::to_string(&selection_message) {
            Ok(json) => json,
            Err(e) => {
                error!("Failed to serialize selection message: {}", e);
                return Err(anyhow!("Failed to serialize selection message: {}", e));
            }
        };

        let clients = self.clients.read().await;
        let mut sent_count = 0;

        for (client_id, sender) in clients.iter() {
            if let Err(e) = sender.send(message_json.clone()) {
                warn!("Failed to send selection update to client {}: {}", client_id, e);
            } else {
                sent_count += 1;
            }
        }

        info!("Sent selection update to {} clients", sent_count);
        Ok(())
    }

    /// Send diagnostics notification to all connected clients
    pub async fn send_diagnostics_update(&self, diagnostics_params: &serde_json::Value) -> Result<()> {
        use crate::mcp::McpMessage;

        // Cache the diagnostics
        {
            let mut cache = self.diagnostics_cache.write().await;
            *cache = diagnostics_params.clone();
            info!("Cached diagnostics update");
        }

        // Create a diagnostics notification in MCP format
        let diagnostics_message = McpMessage::new_notification(
            "diagnostics/updated".to_string(),
            Some(diagnostics_params.clone()),
        );

        let message_json = match serde_json::to_string(&diagnostics_message) {
            Ok(json) => json,
            Err(e) => {
                error!("Failed to serialize diagnostics message: {}", e);
                return Err(anyhow!("Failed to serialize diagnostics message: {}", e));
            }
        };

        let clients = self.clients.read().await;
        let mut sent_count = 0;

        for (client_id, sender) in clients.iter() {
            if let Err(e) = sender.send(message_json.clone()) {
                warn!("Failed to send diagnostics update to client {}: {}", client_id, e);
            } else {
                sent_count += 1;
            }
        }

        info!("Sent diagnostics update to {} clients", sent_count);
        Ok(())
    }
}

impl Clone for McpHandler {
    fn clone(&self) -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::time::{sleep, Duration};

    #[tokio::test]
    async fn test_server_lifecycle() {
        let mut server = WebSocketServer::new(50000, 50010).await.unwrap();

        // Start server
        let (port, auth_token) = server.start().await.unwrap();
        assert!(port >= 50000 && port <= 50010);
        assert!(!auth_token.is_empty());

        // Check status
        let status = server.get_status();
        assert!(status.success);
        assert_eq!(status.port, Some(port));
        assert_eq!(status.auth_token, Some(auth_token));

        // Stop server
        server.stop().await.unwrap();

        // Check status after stop
        let status = server.get_status();
        assert!(!status.success);
        assert!(status.error.is_some());
    }
}