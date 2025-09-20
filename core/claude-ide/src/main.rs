use anyhow::Result;
use tracing::{info, Level};
use tracing_subscriber;

mod server;
mod handshake;
mod frame;
mod mcp;
mod lock_file;
mod cli;

use server::WebSocketServer;
use cli::Cli;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::DEBUG)
        .with_target(false)
        .init();

    let cli = Cli::parse();

    match cli.command {
        cli::Command::Start { port_min, port_max } => {
            info!("Starting Claude IDE WebSocket server");
            let mut server = WebSocketServer::new(port_min, port_max).await?;
            server.run().await?;
        }
        cli::Command::Daemon { port_min, port_max, workspace_folder } => {
            info!("Starting Claude IDE WebSocket server in daemon mode");
            let mut server = WebSocketServer::new(port_min, port_max).await?;
            server.set_workspace_folder(workspace_folder);
            let (port, auth_token) = server.start().await?;

            // Print connection info for caller
            let response = cli::Response {
                success: true,
                port: Some(port),
                auth_token: Some(auth_token),
                error: None,
                connected: Some(false),
            };
            println!("{}", serde_json::to_string(&response)?);

            // Keep running indefinitely with stdin handling
            info!("Server running in daemon mode on port {}. Press Ctrl+C to stop.", port);

            // Handle both stdin commands and Ctrl+C
            tokio::select! {
                // Handle Ctrl+C
                _ = tokio::signal::ctrl_c() => {
                    info!("Received shutdown signal, stopping server...");
                    server.stop().await?;
                }
                // Handle stdin commands (like the non-daemon mode)
                result = server.run() => {
                    if let Err(e) = result {
                        eprintln!("Server error: {}", e);
                    }
                }
            }
        }
        cli::Command::Stop => {
            info!("Stopping Claude IDE server");
            // TODO: Implement graceful shutdown
        }
        cli::Command::Status => {
            info!("Checking Claude IDE server status");
            // TODO: Implement status check
        }
        cli::Command::Test => {
            println!(r#"{{"success": true, "test": "quick"}}"#);
        }
    }

    Ok(())
}