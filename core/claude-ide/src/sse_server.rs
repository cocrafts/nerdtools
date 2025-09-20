use anyhow::{anyhow, Result};
use axum::{
    extract::{Query, State},
    http::{HeaderMap, StatusCode},
    response::sse::{Event, Sse},
    routing::{get, post},
    Json, Router,
};
use futures_util::stream::{self, Stream};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{convert::Infallible, sync::Arc, time::Duration};
use tokio::sync::broadcast;
use tokio_stream::{wrappers::BroadcastStream, StreamExt};
use tower_http::cors::CorsLayer;
use tracing::{debug, error, info, warn};
use uuid::Uuid;

use crate::cli::Response as CliResponse;
use crate::lock_file::LockFileManager;
use crate::mcp::{McpHandler, McpMessage};

#[derive(Debug, Clone, Deserialize)]
pub struct SseParams {
    token: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SseEvent {
    pub event_type: String,
    pub data: Value,
}

pub struct SseServer {
    port_min: u16,
    port_max: u16,
    port: Option<u16>,
    auth_token: Option<String>,
    workspace_folder: Option<String>,
    lock_manager: LockFileManager,
    // Broadcast channel for sending events to SSE clients
    event_sender: broadcast::Sender<SseEvent>,
    mcp_handler: Arc<McpHandler>,
}

impl SseServer {
    pub async fn new(port_min: u16, port_max: u16) -> Result<Self> {
        let (event_sender, _) = broadcast::channel(100);

        Ok(Self {
            port_min,
            port_max,
            port: None,
            auth_token: None,
            workspace_folder: None,
            lock_manager: LockFileManager::new(),
            event_sender,
            mcp_handler: Arc::new(McpHandler::new()),
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

    /// Start the SSE/HTTP server
    pub async fn start(&mut self) -> Result<(u16, String)> {
        let port = self.find_available_port().await?;
        let auth_token = Uuid::new_v4().to_string();

        self.port = Some(port);
        self.auth_token = Some(auth_token.clone());

        // Create lock file
        self.lock_manager.create_lock_file(port, &auth_token, self.workspace_folder.as_deref())?;

        let app_state = AppState {
            auth_token: auth_token.clone(),
            event_sender: self.event_sender.clone(),
            mcp_handler: self.mcp_handler.clone(),
        };

        // Build the router with SSE and HTTP endpoints
        let app = Router::new()
            .route("/sse", get(sse_handler))
            .route("/", post(mcp_handler))
            .route("/messages", post(mcp_handler))
            .layer(CorsLayer::permissive())
            .with_state(app_state);

        let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{}", port)).await?;

        info!("SSE/HTTP server started on port {}", port);

        // Start the server in the background
        tokio::spawn(async move {
            if let Err(e) = axum::serve(listener, app).await {
                error!("Server error: {}", e);
            }
        });

        Ok((port, auth_token))
    }

    /// Stop the server
    pub async fn stop(&mut self) -> Result<()> {
        if let Some(port) = self.port {
            self.lock_manager.remove_lock_file(port)?;
        }

        self.port = None;
        self.auth_token = None;

        info!("SSE server stopped");
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
                connected: Some(true), // SSE connections are harder to track, assume connected if server is running
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

    /// Send an event to all SSE clients
    pub fn send_event(&self, event: SseEvent) -> Result<()> {
        match self.event_sender.send(event) {
            Ok(_) => Ok(()),
            Err(e) => {
                warn!("No SSE clients to send to: {}", e);
                Ok(()) // Not an error, just no clients connected
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

#[derive(Clone)]
struct AppState {
    auth_token: String,
    event_sender: broadcast::Sender<SseEvent>,
    mcp_handler: Arc<McpHandler>,
}

/// SSE endpoint handler - Claude Code connects here to receive events
async fn sse_handler(
    State(state): State<AppState>,
    Query(params): Query<SseParams>,
    headers: HeaderMap,
) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, StatusCode> {
    // Check authentication
    let auth_token = params.token
        .or_else(|| {
            headers.get("Authorization")
                .and_then(|h| h.to_str().ok())
                .and_then(|s| s.strip_prefix("Bearer "))
                .map(|s| s.to_string())
        });

    if auth_token.as_ref() != Some(&state.auth_token) {
        warn!("SSE connection attempt with invalid auth token");
        return Err(StatusCode::UNAUTHORIZED);
    }

    info!("Claude Code connected via SSE");

    // Create event stream from broadcast channel
    let event_stream = BroadcastStream::new(state.event_sender.subscribe())
        .map(|result| {
            match result {
                Ok(sse_event) => {
                    let data = serde_json::to_string(&sse_event.data).unwrap_or_default();
                    Ok(Event::default()
                        .event(sse_event.event_type)
                        .data(data))
                }
                Err(_) => {
                    // Channel error, send a keep-alive
                    Ok(Event::default().comment("keep-alive"))
                }
            }
        });

    // Add periodic keep-alive events
    let keep_alive_stream = stream::repeat(())
        .throttle(Duration::from_secs(30))
        .map(|_| Ok(Event::default().comment("keep-alive")));

    // Merge the event stream with keep-alive stream
    let combined_stream = futures_util::stream::select(event_stream, keep_alive_stream);

    Ok(Sse::new(combined_stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(30))
            .text("keep-alive-text"),
    ))
}

/// HTTP POST endpoint handler - Claude Code sends MCP messages here
async fn mcp_handler(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(payload): Json<Value>,
) -> Result<Json<Value>, StatusCode> {
    // Check authentication
    let auth_token = headers.get("Authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(|s| s.to_string());

    if auth_token.as_ref() != Some(&state.auth_token) {
        warn!("HTTP request with invalid auth token");
        return Err(StatusCode::UNAUTHORIZED);
    }

    debug!("Received MCP message: {}", payload);

    // Parse the MCP message
    let mcp_message: McpMessage = match serde_json::from_value(payload) {
        Ok(msg) => msg,
        Err(e) => {
            error!("Failed to parse MCP message: {}", e);
            return Err(StatusCode::BAD_REQUEST);
        }
    };

    // Handle the message
    match state.mcp_handler.handle_message(mcp_message) {
        Ok(response) => {
            // Only send response for requests (not notifications)
            if response.method != Some("ignored".to_string()) {
                debug!("Sending MCP response: {:?}", response);
                match serde_json::to_value(&response) {
                    Ok(response_value) => Ok(Json(response_value)),
                    Err(e) => {
                        error!("Failed to serialize MCP response: {}", e);
                        Err(StatusCode::INTERNAL_SERVER_ERROR)
                    }
                }
            } else {
                // This was a notification, return empty response
                Ok(Json(json!({})))
            }
        }
        Err(e) => {
            error!("Failed to handle MCP message: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}