use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug)]
pub struct Cli {
    pub command: Command,
}

#[derive(Debug)]
pub enum Command {
    Start { port_min: u16, port_max: u16 },
    Daemon { port_min: u16, port_max: u16, workspace_folder: Option<String> },
    Stop,
    Status,
    Test,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StdinRequest {
    pub method: String,
    pub params: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Response {
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub auth_token: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub connected: Option<bool>,
}

impl Cli {
    pub fn parse() -> Self {
        let args: Vec<String> = env::args().collect();

        if args.len() > 1 {
            match args[1].as_str() {
                "daemon" | "--daemon" | "-d" => {
                    let workspace_folder = if args.len() > 2 && !args[2].starts_with('-') {
                        Some(args[2].clone())
                    } else {
                        None
                    };
                    return Self {
                        command: Command::Daemon {
                            port_min: 50000,
                            port_max: 60000,
                            workspace_folder,
                        },
                    };
                }
                "status" | "--status" | "-s" => {
                    return Self {
                        command: Command::Status,
                    };
                }
                "test" | "--test" | "-t" => {
                    return Self {
                        command: Command::Test,
                    };
                }
                "stop" => {
                    return Self {
                        command: Command::Stop,
                    };
                }
                _ => {}
            }
        }

        // Default to start command with default port range
        Self {
            command: Command::Start {
                port_min: 50000,
                port_max: 60000,
            },
        }
    }
}