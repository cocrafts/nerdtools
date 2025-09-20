use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::VecDeque;
use std::sync::Arc;
use tokio::sync::{mpsc, RwLock, Mutex};
use tracing::{info, error};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McpMessage {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub method: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<Value>,
}

impl McpMessage {
    pub fn new_request(id: Value, method: String, params: Option<Value>) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            id: Some(id),
            method: Some(method),
            params,
            result: None,
            error: None,
        }
    }

    pub fn new_response(id: Option<Value>, result: Option<Value>, error: Option<Value>) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            id,
            method: None,
            params: None,
            result,
            error,
        }
    }

    pub fn new_notification(method: String, params: Option<Value>) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            id: None,
            method: Some(method),
            params,
            result: None,
            error: None,
        }
    }
}

pub struct McpHandler {
    selection_broadcaster: Option<mpsc::UnboundedSender<SelectionUpdate>>,
    diagnostics_cache: Option<Arc<RwLock<Value>>>,
    command_queue: Option<Arc<Mutex<VecDeque<Value>>>>,
}

#[derive(Debug, Clone)]
pub struct SelectionUpdate {
    pub file_path: String,
    pub text: String,
    pub line_start: Option<u32>,
    pub line_end: Option<u32>,
}

impl McpHandler {
    pub fn new() -> Self {
        Self {
            selection_broadcaster: None,
            diagnostics_cache: None,
            command_queue: None,
        }
    }

    pub fn with_selection_broadcaster(mut self, sender: mpsc::UnboundedSender<SelectionUpdate>) -> Self {
        self.selection_broadcaster = Some(sender);
        self
    }

    pub fn with_diagnostics_cache(mut self, cache: Arc<RwLock<Value>>) -> Self {
        self.diagnostics_cache = Some(cache);
        self
    }

    pub fn with_command_queue(mut self, queue: Arc<Mutex<VecDeque<Value>>>) -> Self {
        self.command_queue = Some(queue);
        self
    }

    pub fn handle_message(&self, message: McpMessage) -> Result<McpMessage> {
        let method = message.method.as_deref().unwrap_or("");

        match method {
            "initialize" => self.handle_initialize(message),
            "notifications/initialized" => self.handle_initialized_notification(message),
            "prompts/list" => self.handle_prompts_list(message),
            "tools/list" => self.handle_tools_list(message),
            "tools/call" => self.handle_tools_call(message),
            "resources/list" => self.handle_resources_list(message),
            "resources/read" => self.handle_resources_read(message),
            "at_mentioned" => self.handle_at_mentioned(message),
            _ => {
                // For notifications (no id), don't send error response
                if message.id.is_none() {
                    // This is a notification, just ignore unknown ones
                    return Ok(McpMessage::new_notification("ignored".to_string(), None));
                }

                let error = json!({
                    "code": -32601,
                    "message": "Method not found"
                });
                Ok(McpMessage::new_response(message.id, None, Some(error)))
            }
        }
    }

    fn handle_initialize(&self, message: McpMessage) -> Result<McpMessage> {
        // Extract the protocol version from the client request
        let client_version = message.params
            .as_ref()
            .and_then(|p| p.get("protocolVersion"))
            .and_then(|v| v.as_str())
            .unwrap_or("2024-11-05");

        let result = json!({
            "protocolVersion": client_version,
            "capabilities": {
                "tools": { "listChanged": true },
                "resources": { "subscribe": true, "listChanged": true },
                "prompts": { "listChanged": true },
                "logging": {}
            },
            "serverInfo": {
                "name": "claudecode-neovim",
                "version": "0.1.0"
            }
        });

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_initialized_notification(&self, _message: McpMessage) -> Result<McpMessage> {
        // This is a notification, no response needed
        Ok(McpMessage::new_notification("ignored".to_string(), None))
    }

    fn handle_prompts_list(&self, message: McpMessage) -> Result<McpMessage> {
        let result = json!({
            "prompts": []
        });

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_tools_list(&self, message: McpMessage) -> Result<McpMessage> {
        let result = json!({
            "tools": [
                {
                    "name": "getDiagnostics",
                    "description": "Get language diagnostics (errors, warnings) from the editor",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "uri": {
                                "type": "string",
                                "description": "Optional file URI to get diagnostics for. If not provided, gets diagnostics for all open files."
                            }
                        },
                        "additionalProperties": false
                    }
                },
                {
                    "name": "buffer_content",
                    "description": "Get content of current buffer in Neovim",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "bufnr": {"type": "integer", "description": "Buffer number"}
                        }
                    }
                },
                {
                    "name": "openFile",
                    "description": "Open a file in the editor and optionally navigate to a specific line",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "filePath": {"type": "string", "description": "Path to the file to open"},
                            "startLine": {"type": "integer", "description": "Line number to navigate to (1-indexed, optional)"},
                            "endLine": {"type": "integer", "description": "End line for selection range (optional)"}
                        },
                        "required": ["filePath"]
                    }
                },
                {
                    "name": "show_diff",
                    "description": "Show diff in Neovim",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "original": {"type": "string", "description": "Original file path"},
                            "modified": {"type": "string", "description": "Modified content"}
                        },
                        "required": ["original", "modified"]
                    }
                },
                {
                    "name": "get_selection",
                    "description": "Get current selection in Neovim",
                    "inputSchema": {
                        "type": "object",
                        "properties": {}
                    }
                },
                {
                    "name": "run_command",
                    "description": "Run a Neovim command",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "command": {"type": "string", "description": "Vim command to execute"}
                        },
                        "required": ["command"]
                    }
                }
            ]
        });

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_tools_call(&self, message: McpMessage) -> Result<McpMessage> {
        let params = message.params.as_ref()
            .ok_or_else(|| anyhow!("Missing params for tools/call"))?;

        let tool_name = params.get("name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow!("Missing tool name"))?;

        let result = match tool_name {
            "openFile" => {
                // Extract parameters
                let file_path = params.get("arguments")
                    .and_then(|args| args.get("filePath"))
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| anyhow!("Missing filePath parameter"))?;

                let start_line = params.get("arguments")
                    .and_then(|args| args.get("startLine"))
                    .and_then(|v| v.as_i64())
                    .map(|v| v as u32);

                let end_line = params.get("arguments")
                    .and_then(|args| args.get("endLine"))
                    .and_then(|v| v.as_i64())
                    .map(|v| v as u32);

                // Add command to queue for Neovim to retrieve via TCP
                if let Some(queue) = &self.command_queue {
                    let command = json!({
                        "type": "openFile",
                        "filePath": file_path,
                        "startLine": start_line,
                        "endLine": end_line
                    });

                    match queue.try_lock() {
                        Ok(mut q) => {
                            q.push_back(command.clone());
                            info!("Queued openFile command for {}", file_path);
                        }
                        Err(e) => {
                            error!("Failed to lock command queue: {}", e);
                        }
                    }
                } else {
                    error!("No command queue available!");
                }

                // Return success response
                json!({
                    "content": [{
                        "type": "text",
                        "text": format!("Opened file: {}", file_path)
                    }]
                })
            }
            "getDiagnostics" | "get_diagnostics" => {
                // Get diagnostics from cache
                let diagnostics = if let Some(cache) = &self.diagnostics_cache {
                    // Use try_read to avoid blocking
                    let cached_diagnostics = if let Ok(cache_guard) = cache.try_read() {
                        cache_guard.clone()
                    } else {
                        json!({})
                    };

                    // Format the diagnostics in the same way as claudecode.nvim
                    if let Some(diagnostics_map) = cached_diagnostics.get("diagnostics").and_then(|d| d.as_object()) {
                        let mut formatted_diagnostics = Vec::new();

                        for (file_path, file_diagnostics) in diagnostics_map {
                            if let Some(diag_array) = file_diagnostics.as_array() {
                                for diag in diag_array {
                                    formatted_diagnostics.push(json!({
                                        "type": "text",
                                        "text": serde_json::to_string(&json!({
                                            "filePath": file_path,
                                            "line": diag.get("line").and_then(|l| l.as_i64()).unwrap_or(1),
                                            "character": diag.get("character").and_then(|c| c.as_i64()).unwrap_or(1),
                                            "severity": diag.get("severity").and_then(|s| s.as_i64()).unwrap_or(1),
                                            "message": diag.get("message").and_then(|m| m.as_str()).unwrap_or(""),
                                            "source": diag.get("source").and_then(|s| s.as_str()).unwrap_or("")
                                        })).unwrap()
                                    }));
                                }
                            }
                        }

                        json!({
                            "content": formatted_diagnostics
                        })
                    } else {
                        json!({
                            "content": [{
                                "type": "text",
                                "text": "No diagnostics available"
                            }]
                        })
                    }
                } else {
                    json!({
                        "content": [{
                            "type": "text",
                            "text": "Diagnostics cache not initialized"
                        }]
                    })
                };
                diagnostics
            }
            _ => {
                json!({
                    "content": [{
                        "type": "text",
                        "text": format!("Tool {} called successfully", tool_name)
                    }]
                })
            }
        };

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_resources_list(&self, message: McpMessage) -> Result<McpMessage> {
        let result = json!({
            "resources": [
                {
                    "name": "project",
                    "description": "Current project information",
                    "uri": "neovim://project",
                    "mimeType": "application/json"
                },
                {
                    "name": "buffers",
                    "description": "Open buffers",
                    "uri": "neovim://buffers",
                    "mimeType": "application/json"
                }
            ]
        });

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_resources_read(&self, message: McpMessage) -> Result<McpMessage> {
        let params = message.params.as_ref()
            .ok_or_else(|| anyhow!("Missing params for resources/read"))?;

        let uri = params.get("uri")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow!("Missing URI"))?;

        let result = json!({
            "contents": [{
                "uri": uri,
                "mimeType": "application/json",
                "text": r#"{"placeholder": true}"#
            }]
        });

        Ok(McpMessage::new_response(message.id, Some(result), None))
    }

    fn handle_at_mentioned(&self, message: McpMessage) -> Result<McpMessage> {
        // Extract parameters from the at_mentioned notification
        if let Some(params) = &message.params {
            let file_path = params.get("filePath")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let text = params.get("text")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let line_start = params.get("lineStart")
                .and_then(|v| v.as_u64())
                .map(|v| v as u32);
            let line_end = params.get("lineEnd")
                .and_then(|v| v.as_u64())
                .map(|v| v as u32);

            // Send selection update to broadcaster if available
            if let Some(broadcaster) = &self.selection_broadcaster {
                let selection_update = SelectionUpdate {
                    file_path: file_path.to_string(),
                    text: text.to_string(),
                    line_start,
                    line_end,
                };

                if let Err(e) = broadcaster.send(selection_update) {
                    eprintln!("Failed to broadcast selection update: {}", e);
                }
            }
        }

        // This is a notification, no response needed
        Ok(McpMessage::new_notification("ignored".to_string(), None))
    }
}

impl Default for McpHandler {
    fn default() -> Self {
        Self::new()
    }
}

pub fn parse_mcp_message(data: &str) -> Result<McpMessage> {
    serde_json::from_str(data).map_err(|e| anyhow!("Failed to parse MCP message: {}", e))
}

pub fn serialize_mcp_message(message: &McpMessage) -> Result<String> {
    serde_json::to_string(message).map_err(|e| anyhow!("Failed to serialize MCP message: {}", e))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_initialize_message() {
        let handler = McpHandler::new();
        let init_msg = McpMessage::new_request(
            json!(1),
            "initialize".to_string(),
            Some(json!({
                "protocolVersion": "2024-11-05",
                "capabilities": {}
            }))
        );

        let response = handler.handle_message(init_msg).unwrap();
        assert!(response.result.is_some());
        assert!(response.error.is_none());

        let result = response.result.unwrap();
        assert_eq!(result["protocolVersion"], "2024-11-05");
        assert_eq!(result["serverInfo"]["name"], "claude-ide-rust");
    }

    #[test]
    fn test_tools_list_message() {
        let handler = McpHandler::new();
        let tools_msg = McpMessage::new_request(
            json!(2),
            "tools/list".to_string(),
            None
        );

        let response = handler.handle_message(tools_msg).unwrap();
        assert!(response.result.is_some());
        assert!(response.error.is_none());

        let result = response.result.unwrap();
        let tools = result["tools"].as_array().unwrap();
        assert!(!tools.is_empty());
        assert_eq!(tools[0]["name"], "buffer_content");
    }

    #[test]
    fn test_unknown_method() {
        let handler = McpHandler::new();
        let unknown_msg = McpMessage::new_request(
            json!(3),
            "unknown/method".to_string(),
            None
        );

        let response = handler.handle_message(unknown_msg).unwrap();
        assert!(response.result.is_none());
        assert!(response.error.is_some());

        let error = response.error.unwrap();
        assert_eq!(error["code"], -32601);
    }

    #[test]
    fn test_parse_and_serialize() {
        let json_str = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
        let message = parse_mcp_message(json_str).unwrap();

        assert_eq!(message.jsonrpc, "2.0");
        assert_eq!(message.id, Some(json!(1)));
        assert_eq!(message.method, Some("initialize".to_string()));

        let serialized = serialize_mcp_message(&message).unwrap();
        let reparsed = parse_mcp_message(&serialized).unwrap();
        assert_eq!(message.id, reparsed.id);
        assert_eq!(message.method, reparsed.method);
    }
}