use anyhow::{anyhow, Result};
use fastwebsockets::{FragmentCollectorRead, Frame, OpCode, Payload, WebSocket};
use futures_util::{SinkExt, StreamExt};
use hyper::{body::Incoming, upgrade::Upgraded, Request, Response};
use hyper_util::rt::TokioIo;
use rmcp::{
    handler::server::{
        resource::{ResourceHandler, ResourcesCapability},
        tool::{ToolHandler, ToolsCapability},
        ServerHandlers,
    },
    model::{Content, InitializeResult, ServerCapabilities, ServerInfo, ToolCallResult},
    service::{serve_with_handler, RoleServer, RxJsonRpcMessage, TxJsonRpcMessage},
    transport::sink_stream::SinkStreamTransport,
};
use serde_json::{json, Value};
use std::{collections::HashMap, future::Future, pin::Pin, sync::Arc, task::Poll};
use tokio::sync::{broadcast, mpsc, RwLock};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use crate::cli::Response as CliResponse;
use crate::lock_file::LockFileManager;

type Clients = Arc<RwLock<HashMap<String, mpsc::UnboundedSender<String>>>>;

pub struct WebSocketMcpServer {
    port_min: u16,
    port_max: u16,
    port: Option<u16>,
    auth_token: Option<String>,
    workspace_folder: Option<String>,
    lock_manager: LockFileManager,
    clients: Clients,
}

impl WebSocketMcpServer {
    pub async fn new(port_min: u16, port_max: u16) -> Result<Self> {
        Ok(Self {
            port_min,
            port_max,
            port: None,
            auth_token: None,
            workspace_folder: None,
            lock_manager: LockFileManager::new(),
            clients: Arc::new(RwLock::new(HashMap::new())),
        })
    }

    pub fn set_workspace_folder(&mut self, workspace_folder: Option<String>) {
        self.workspace_folder = workspace_folder;
    }

    /// Find an available port in the range
    async fn find_available_port(&self) -> Result<u16> {
        for port in self.port_min..=self.port_max {
            if let Ok(listener) = tokio::net::TcpListener::bind(format!("127.0.0.1:{}", port)).await {
                drop(listener);
                return Ok(port);
            }
        }
        Err(anyhow!("No available ports in range {}-{}", self.port_min, self.port_max))
    }

    /// Start the WebSocket MCP server
    pub async fn start(&mut self) -> Result<(u16, String)> {
        let port = self.find_available_port().await?;
        let auth_token = Uuid::new_v4().to_string();

        self.port = Some(port);
        self.auth_token = Some(auth_token.clone());

        // Create lock file
        self.lock_manager.create_lock_file(port, &auth_token, self.workspace_folder.as_deref())?;

        let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{}", port)).await?;
        let clients = self.clients.clone();
        let server_auth_token = auth_token.clone();

        // Start the server
        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, _)) => {
                        let clients = clients.clone();
                        let auth_token = server_auth_token.clone();

                        tokio::spawn(async move {
                            if let Err(e) = handle_connection(stream, clients, auth_token).await {
                                error!("Connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        error!("Failed to accept connection: {}", e);
                        break;
                    }
                }
            }
        });

        info!("WebSocket MCP server started on port {}", port);
        Ok((port, auth_token))
    }

    /// Stop the server
    pub async fn stop(&mut self) -> Result<()> {
        if let Some(port) = self.port {
            self.lock_manager.remove_lock_file(port)?;
        }

        self.port = None;
        self.auth_token = None;
        self.clients.write().await.clear();

        info!("WebSocket MCP server stopped");
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

    /// Run the server with stdin command handling (for compatibility)
    pub async fn run(&mut self) -> Result<()> {
        use tokio::io::{AsyncBufReadExt, BufReader};

        // Handle stdin commands for compatibility with existing CLI
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
        use crate::cli::StdinRequest;

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
            _ => Err(anyhow!("Unknown method: {}", request.method)),
        }
    }
}

async fn handle_connection(
    stream: tokio::net::TcpStream,
    clients: Clients,
    auth_token: String,
) -> Result<()> {
    // Perform HTTP upgrade to WebSocket
    let ws_stream = tokio_ws::accept(stream, |req: &Request<()>| {
        // Validate authentication
        let auth_header = req.headers()
            .get("x-claude-code-ide-authorization")
            .and_then(|h| h.to_str().ok());

        if auth_header != Some(&auth_token) {
            warn!("WebSocket connection attempt with invalid auth token");
            return Err(hyper::Response::builder()
                .status(401)
                .body(())
                .unwrap());
        }

        info!("Claude Code connected via WebSocket");
        Ok(hyper::Response::builder()
            .status(101)
            .body(())
            .unwrap())
    }).await?;

    // Create WebSocket adapter for rmcp
    let (ws_sink, ws_stream) = ws_stream.split();

    // Convert WebSocket to rmcp message streams
    let message_stream = ws_stream.map(|result| {
        match result {
            Ok(msg) => {
                match msg.opcode() {
                    tokio_ws::OpCode::Text => {
                        let text = String::from_utf8_lossy(msg.payload());
                        debug!("Received WebSocket message: {}", text);

                        match serde_json::from_str::<RxJsonRpcMessage<RoleServer>>(&text) {
                            Ok(mcp_msg) => Some(mcp_msg),
                            Err(e) => {
                                error!("Failed to parse MCP message: {}", e);
                                None
                            }
                        }
                    }
                    _ => None,
                }
            }
            Err(e) => {
                error!("WebSocket error: {}", e);
                None
            }
        }
    }).filter_map(|msg| async move { msg });

    let message_sink = ws_sink.with(|msg: TxJsonRpcMessage<RoleServer>| {
        async move {
            match serde_json::to_string(&msg) {
                Ok(text) => {
                    debug!("Sending WebSocket message: {}", text);
                    Ok(tokio_ws::Message::text(text))
                }
                Err(e) => {
                    error!("Failed to serialize MCP message: {}", e);
                    Err(e.into())
                }
            }
        }
    });

    // Create rmcp transport
    let transport = SinkStreamTransport::new(message_sink, message_stream);

    // Create MCP handlers
    let handlers = create_mcp_handlers();

    // Run the MCP server
    serve_with_handler(transport, handlers).await?;

    Ok(())
}

fn create_mcp_handlers() -> ServerHandlers {
    let mut handlers = ServerHandlers::new();

    // Add tool handlers
    handlers.tool.add_handler(
        "buffer_content",
        Box::new(BufferContentHandler),
    );

    handlers.tool.add_handler(
        "open_file",
        Box::new(OpenFileHandler),
    );

    // Add resource handlers
    handlers.resource.add_handler(
        "project",
        Box::new(ProjectResourceHandler),
    );

    handlers
}

// Tool implementations
struct BufferContentHandler;

impl ToolHandler for BufferContentHandler {
    fn call(
        &self,
        _arguments: Value,
    ) -> Pin<Box<dyn Future<Output = Result<ToolCallResult, rmcp::RmcpError>> + Send + '_>> {
        Box::pin(async move {
            Ok(ToolCallResult {
                content: vec![Content::Text {
                    text: "Mock buffer content".to_string(),
                }],
                is_error: Some(false),
            })
        })
    }
}

struct OpenFileHandler;

impl ToolHandler for OpenFileHandler {
    fn call(
        &self,
        arguments: Value,
    ) -> Pin<Box<dyn Future<Output = Result<ToolCallResult, rmcp::RmcpError>> + Send + '_>> {
        Box::pin(async move {
            let file_path = arguments.get("filePath")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown");

            Ok(ToolCallResult {
                content: vec![Content::Text {
                    text: format!("Opened file: {}", file_path),
                }],
                is_error: Some(false),
            })
        })
    }
}

struct ProjectResourceHandler;

impl ResourceHandler for ProjectResourceHandler {
    fn read(
        &self,
        _uri: &str,
    ) -> Pin<Box<dyn Future<Output = Result<Vec<Content>, rmcp::RmcpError>> + Send + '_>> {
        Box::pin(async move {
            Ok(vec![Content::Text {
                text: json!({
                    "name": "nerdtools",
                    "path": "/Users/le/nerdtools/core"
                }).to_string(),
            }])
        })
    }
}

// Simple WebSocket library - using existing fastwebsockets but need to adapt
mod tokio_ws {
    use super::*;

    pub use fastwebsockets::OpCode;

    pub struct Message {
        payload: Vec<u8>,
        opcode: OpCode,
    }

    impl Message {
        pub fn text(text: String) -> Self {
            Self {
                payload: text.into_bytes(),
                opcode: OpCode::Text,
            }
        }

        pub fn payload(&self) -> &[u8] {
            &self.payload
        }

        pub fn opcode(&self) -> OpCode {
            self.opcode
        }
    }

    pub async fn accept<F>(
        stream: tokio::net::TcpStream,
        callback: F
    ) -> Result<impl futures_util::Stream<Item = Result<Message, anyhow::Error>> + futures_util::Sink<Message, Error = anyhow::Error>>
    where
        F: FnOnce(&Request<()>) -> Result<Response<()>, Response<()>>
    {
        // This is a simplified adapter - in reality we'd use fastwebsockets properly
        // For now, return a mock stream/sink
        todo!("Implement WebSocket adapter using fastwebsockets")
    }
}