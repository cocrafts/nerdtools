use anyhow::{anyhow, Result};
use base64::{engine::general_purpose, Engine as _};
use sha1::{Digest, Sha1};
use std::collections::HashMap;

const WS_MAGIC_STRING: &str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

/// Parse HTTP headers from request string
pub fn parse_http_headers(request: &str) -> HashMap<String, String> {
    let mut headers = HashMap::new();
    let lines: Vec<&str> = request.split("\r\n").collect();

    for line in lines.iter().skip(1) {
        let line = line.trim();
        if line.is_empty() {
            break;
        }

        if let Some(colon_pos) = line.find(':') {
            let name = line[..colon_pos].trim().to_lowercase();
            let value = line[colon_pos + 1..].trim().to_string();
            headers.insert(name, value);
        }
    }

    headers
}

/// Generate WebSocket accept key from client key
pub fn generate_accept_key(client_key: &str) -> Result<String> {
    // Concatenate client key with magic string
    let combined = format!("{}{}", client_key, WS_MAGIC_STRING);

    // SHA1 hash
    let mut hasher = Sha1::new();
    hasher.update(combined.as_bytes());
    let hash = hasher.finalize();

    // Base64 encode
    Ok(general_purpose::STANDARD.encode(hash))
}

/// Check if an HTTP request is a valid WebSocket upgrade request
pub fn validate_upgrade_request(request: &str, expected_auth_token: Option<&str>) -> Result<HashMap<String, String>> {
    let headers = parse_http_headers(request);

    // Check for required headers
    let upgrade = headers.get("upgrade").map(|s| s.to_lowercase());
    if upgrade.as_deref() != Some("websocket") {
        return Err(anyhow!("Missing or invalid Upgrade header"));
    }

    let connection = headers.get("connection").map(|s| s.to_lowercase());
    if !connection.as_deref().unwrap_or("").contains("upgrade") {
        return Err(anyhow!("Missing or invalid Connection header"));
    }

    let ws_key = headers.get("sec-websocket-key");
    if ws_key.is_none() {
        return Err(anyhow!("Missing Sec-WebSocket-Key header"));
    }

    let ws_version = headers.get("sec-websocket-version");
    if ws_version.map(|s| s.as_str()) != Some("13") {
        return Err(anyhow!("Missing or unsupported Sec-WebSocket-Version header"));
    }

    // Validate WebSocket key format (should be base64 encoded 16 bytes)
    let key = ws_key.unwrap();
    if key.len() != 24 {
        return Err(anyhow!("Invalid Sec-WebSocket-Key format"));
    }

    // Validate authentication token if required
    if let Some(expected_token) = expected_auth_token {
        if expected_token.is_empty() {
            return Err(anyhow!("Server configuration error: invalid expected authentication token"));
        }

        let auth_header = headers.get("x-claude-code-ide-authorization");
        if auth_header.is_none() {
            return Err(anyhow!("Missing authentication header: x-claude-code-ide-authorization"));
        }

        let auth_token = auth_header.unwrap();
        if auth_token.is_empty() {
            return Err(anyhow!("Authentication token too short (min 10 characters)"));
        }

        if auth_token.len() > 500 {
            return Err(anyhow!("Authentication token too long (max 500 characters)"));
        }

        if auth_token.len() < 10 {
            return Err(anyhow!("Authentication token too short (min 10 characters)"));
        }

        if auth_token != expected_token {
            return Err(anyhow!("Invalid authentication token"));
        }
    }

    Ok(headers)
}

/// Generate a WebSocket handshake response
pub fn create_handshake_response(client_key: &str, protocol: Option<&str>) -> Result<String> {
    let accept_key = generate_accept_key(client_key)?;

    let mut response = vec![
        "HTTP/1.1 101 Switching Protocols".to_string(),
        "Upgrade: websocket".to_string(),
        "Connection: Upgrade".to_string(),
        format!("Sec-WebSocket-Accept: {}", accept_key),
    ];

    if let Some(proto) = protocol {
        response.push(format!("Sec-WebSocket-Protocol: {}", proto));
    }

    // Add empty line to end headers
    response.push(String::new());
    response.push(String::new());

    Ok(response.join("\r\n"))
}

/// Parse the HTTP request line
pub fn parse_request_line(request: &str) -> Option<(String, String, String)> {
    let first_line = request.lines().next()?;
    let parts: Vec<&str> = first_line.split_whitespace().collect();

    if parts.len() >= 3 {
        Some((parts[0].to_string(), parts[1].to_string(), parts[2].to_string()))
    } else {
        None
    }
}

/// Check if the request is for the WebSocket endpoint
pub fn is_websocket_endpoint(request: &str) -> bool {
    if let Some((method, _path, version)) = parse_request_line(request) {
        method == "GET" && version.starts_with("HTTP/1.1")
    } else {
        false
    }
}

/// Create a WebSocket handshake error response
pub fn create_error_response(code: u16, message: &str) -> String {
    let status_text = match code {
        400 => "Bad Request",
        404 => "Not Found",
        426 => "Upgrade Required",
        500 => "Internal Server Error",
        _ => "Error",
    };

    format!(
        "HTTP/1.1 {} {}\r\nContent-Type: text/plain\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        code,
        status_text,
        message.len(),
        message
    )
}

/// Process a complete WebSocket handshake
pub fn process_handshake(request: &str, expected_auth_token: Option<&str>) -> (bool, String, Option<HashMap<String, String>>) {
    // Check if it's a valid WebSocket endpoint request
    if !is_websocket_endpoint(request) {
        let response = create_error_response(404, "WebSocket endpoint not found");
        return (false, response, None);
    }

    // Validate the upgrade request
    match validate_upgrade_request(request, expected_auth_token) {
        Ok(headers) => {
            // Generate handshake response
            let client_key = headers.get("sec-websocket-key").unwrap();
            let protocol = headers.get("sec-websocket-protocol");

            match create_handshake_response(client_key, protocol.map(|s| s.as_str())) {
                Ok(response) => (true, response, Some(headers)),
                Err(_) => {
                    let error_response = create_error_response(500, "Failed to generate WebSocket handshake response");
                    (false, error_response, None)
                }
            }
        }
        Err(error) => {
            let error_message = format!("Bad WebSocket upgrade request: {}", error);
            let response = create_error_response(400, &error_message);
            (false, response, None)
        }
    }
}

/// Check if a request buffer contains a complete HTTP request
pub fn extract_http_request(buffer: &str) -> (bool, Option<String>, String) {
    // Look for the end of HTTP headers (double CRLF)
    if let Some(header_end) = buffer.find("\r\n\r\n") {
        // For WebSocket upgrade, there should be no body
        let request = buffer[..header_end + 4].to_string();
        let remaining = buffer[header_end + 4..].to_string();
        (true, Some(request), remaining)
    } else {
        (false, None, buffer.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_accept_key() {
        let client_key = "dGhlIHNhbXBsZSBub25jZQ==";
        let expected = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";
        assert_eq!(generate_accept_key(client_key).unwrap(), expected);
    }

    #[test]
    fn test_parse_http_headers() {
        let request = "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n\r\n";
        let headers = parse_http_headers(request);
        assert_eq!(headers.get("host"), Some(&"localhost".to_string()));
        assert_eq!(headers.get("upgrade"), Some(&"websocket".to_string()));
    }
}