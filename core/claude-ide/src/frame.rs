use anyhow::{anyhow, Result};
use std::fmt;

/// WebSocket opcodes as defined in RFC 6455
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OpCode {
    Continuation = 0x0,
    Text = 0x1,
    Binary = 0x2,
    Close = 0x8,
    Ping = 0x9,
    Pong = 0xA,
}

impl OpCode {
    pub fn from_u8(value: u8) -> Option<Self> {
        match value {
            0x0 => Some(OpCode::Continuation),
            0x1 => Some(OpCode::Text),
            0x2 => Some(OpCode::Binary),
            0x8 => Some(OpCode::Close),
            0x9 => Some(OpCode::Ping),
            0xA => Some(OpCode::Pong),
            _ => None,
        }
    }

    pub fn is_control_frame(self) -> bool {
        matches!(self, OpCode::Close | OpCode::Ping | OpCode::Pong)
    }
}

impl fmt::Display for OpCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            OpCode::Continuation => write!(f, "CONTINUATION"),
            OpCode::Text => write!(f, "TEXT"),
            OpCode::Binary => write!(f, "BINARY"),
            OpCode::Close => write!(f, "CLOSE"),
            OpCode::Ping => write!(f, "PING"),
            OpCode::Pong => write!(f, "PONG"),
        }
    }
}

/// WebSocket frame structure
#[derive(Debug, Clone)]
pub struct WebSocketFrame {
    pub fin: bool,
    pub opcode: OpCode,
    pub masked: bool,
    pub payload_length: usize,
    pub mask: Option<[u8; 4]>,
    pub payload: Vec<u8>,
}

impl WebSocketFrame {
    pub fn new(fin: bool, opcode: OpCode, payload: Vec<u8>) -> Self {
        Self {
            fin,
            opcode,
            masked: false,
            payload_length: payload.len(),
            mask: None,
            payload,
        }
    }

    /// Create a text frame
    pub fn text(text: &str) -> Self {
        Self::new(true, OpCode::Text, text.as_bytes().to_vec())
    }

    /// Create a binary frame
    pub fn binary(data: Vec<u8>) -> Self {
        Self::new(true, OpCode::Binary, data)
    }

    /// Create a close frame
    pub fn close(code: Option<u16>, reason: Option<&str>) -> Self {
        let mut payload = Vec::new();

        if let Some(code) = code {
            payload.extend_from_slice(&code.to_be_bytes());
            if let Some(reason) = reason {
                payload.extend_from_slice(reason.as_bytes());
            }
        }

        Self::new(true, OpCode::Close, payload)
    }

    /// Create a ping frame
    pub fn ping(data: Option<&[u8]>) -> Self {
        Self::new(true, OpCode::Ping, data.unwrap_or(&[]).to_vec())
    }

    /// Create a pong frame
    pub fn pong(data: Option<&[u8]>) -> Self {
        Self::new(true, OpCode::Pong, data.unwrap_or(&[]).to_vec())
    }

    /// Get the text payload (only valid for text frames)
    pub fn text_payload(&self) -> Result<String> {
        if self.opcode != OpCode::Text {
            return Err(anyhow!("Frame is not a text frame"));
        }
        String::from_utf8(self.payload.clone()).map_err(|e| anyhow!("Invalid UTF-8: {}", e))
    }

    /// Get close code and reason (only valid for close frames)
    pub fn close_info(&self) -> (u16, String) {
        if self.opcode != OpCode::Close {
            return (1000, String::new());
        }

        if self.payload.len() >= 2 {
            let code = u16::from_be_bytes([self.payload[0], self.payload[1]]);
            let reason = if self.payload.len() > 2 {
                String::from_utf8_lossy(&self.payload[2..]).to_string()
            } else {
                String::new()
            };
            (code, reason)
        } else {
            (1000, String::new())
        }
    }
}

/// Parse a WebSocket frame from binary data
pub fn parse_frame(data: &[u8]) -> Result<(Option<WebSocketFrame>, usize)> {
    if data.len() < 2 {
        return Ok((None, 0)); // Need at least 2 bytes for basic header
    }

    let mut pos = 0;
    let byte1 = data[pos];
    let byte2 = data[pos + 1];
    pos += 2;

    // Parse first byte: FIN + RSV + Opcode
    let fin = (byte1 & 0x80) != 0;
    let rsv1 = (byte1 & 0x40) != 0;
    let rsv2 = (byte1 & 0x20) != 0;
    let rsv3 = (byte1 & 0x10) != 0;
    let opcode_value = byte1 & 0x0F;

    // Parse second byte: MASK + Payload length
    let masked = (byte2 & 0x80) != 0;
    let payload_len = (byte2 & 0x7F) as usize;

    // Validate opcode
    let opcode = OpCode::from_u8(opcode_value)
        .ok_or_else(|| anyhow!("Invalid opcode: {}", opcode_value))?;

    // Check for reserved bits (must be 0)
    if rsv1 || rsv2 || rsv3 {
        return Err(anyhow!("Protocol error: reserved bits set"));
    }

    // Control frames must have fin=1 and payload ≤ 125
    if opcode.is_control_frame() {
        if !fin {
            return Err(anyhow!("Control frames must not be fragmented"));
        }
        if payload_len > 125 {
            return Err(anyhow!("Control frame payload too large"));
        }
    }

    // Determine actual payload length
    let actual_payload_len = if payload_len == 126 {
        if data.len() < pos + 2 {
            return Ok((None, 0)); // Need 2 more bytes
        }
        let len = u16::from_be_bytes([data[pos], data[pos + 1]]) as usize;
        pos += 2;
        len
    } else if payload_len == 127 {
        if data.len() < pos + 8 {
            return Ok((None, 0)); // Need 8 more bytes
        }
        let len = u64::from_be_bytes([
            data[pos], data[pos + 1], data[pos + 2], data[pos + 3],
            data[pos + 4], data[pos + 5], data[pos + 6], data[pos + 7],
        ]) as usize;
        pos += 8;

        // Prevent extremely large payloads (DOS protection)
        if len > 100 * 1024 * 1024 {
            return Err(anyhow!("Payload too large: {} bytes", len));
        }
        len
    } else {
        payload_len
    };

    // Read mask if present
    let mask = if masked {
        if data.len() < pos + 4 {
            return Ok((None, 0)); // Need 4 mask bytes
        }
        let mask_bytes = [data[pos], data[pos + 1], data[pos + 2], data[pos + 3]];
        pos += 4;
        Some(mask_bytes)
    } else {
        None
    };

    // Check if we have enough data for payload
    if data.len() < pos + actual_payload_len {
        return Ok((None, 0)); // Incomplete frame
    }

    // Read payload
    let mut payload = data[pos..pos + actual_payload_len].to_vec();
    pos += actual_payload_len;

    // Unmask payload if needed
    if let Some(mask_key) = mask {
        for (i, byte) in payload.iter_mut().enumerate() {
            *byte ^= mask_key[i % 4];
        }
    }

    // Validate text frame payload is valid UTF-8
    if opcode == OpCode::Text && String::from_utf8(payload.clone()).is_err() {
        return Err(anyhow!("Invalid UTF-8 in text frame"));
    }

    // Basic validation for close frame payload
    if opcode == OpCode::Close && actual_payload_len > 0 {
        if actual_payload_len == 1 {
            return Err(anyhow!("Close frame with 1 byte payload is invalid"));
        }
        // Validate reason text is UTF-8
        if actual_payload_len > 2 {
            let reason = &payload[2..];
            if String::from_utf8(reason.to_vec()).is_err() {
                return Err(anyhow!("Invalid UTF-8 in close reason"));
            }
        }
    }

    let frame = WebSocketFrame {
        fin,
        opcode,
        masked,
        payload_length: actual_payload_len,
        mask,
        payload,
    };

    Ok((Some(frame), pos))
}

/// Create a WebSocket frame as binary data
pub fn create_frame(opcode: OpCode, payload: &[u8], fin: bool, masked: bool) -> Vec<u8> {
    let mut frame_data = Vec::new();

    // First byte: FIN + RSV + Opcode
    let mut byte1 = opcode as u8;
    if fin {
        byte1 |= 0x80; // Set FIN bit
    }
    frame_data.push(byte1);

    // Payload length and mask bit
    let payload_len = payload.len();
    let mut byte2 = 0u8;
    if masked {
        byte2 |= 0x80; // Set MASK bit
    }

    if payload_len < 126 {
        byte2 |= payload_len as u8;
        frame_data.push(byte2);
    } else if payload_len < 65536 {
        byte2 |= 126;
        frame_data.push(byte2);
        frame_data.extend_from_slice(&(payload_len as u16).to_be_bytes());
    } else {
        byte2 |= 127;
        frame_data.push(byte2);
        frame_data.extend_from_slice(&(payload_len as u64).to_be_bytes());
    }

    // Add mask if needed
    let mask = if masked {
        // Generate random 4-byte mask (in production, use proper random)
        let mask_bytes = [
            (payload_len & 0xFF) as u8,
            ((payload_len >> 8) & 0xFF) as u8,
            ((payload_len >> 16) & 0xFF) as u8,
            ((payload_len >> 24) & 0xFF) as u8,
        ];
        frame_data.extend_from_slice(&mask_bytes);
        Some(mask_bytes)
    } else {
        None
    };

    // Add payload (masked if needed)
    if let Some(mask_key) = mask {
        for (i, &byte) in payload.iter().enumerate() {
            frame_data.push(byte ^ mask_key[i % 4]);
        }
    } else {
        frame_data.extend_from_slice(payload);
    }

    frame_data
}

/// Create a text frame
pub fn create_text_frame(text: &str) -> Vec<u8> {
    create_frame(OpCode::Text, text.as_bytes(), true, false)
}

/// Create a binary frame
pub fn create_binary_frame(data: &[u8]) -> Vec<u8> {
    create_frame(OpCode::Binary, data, true, false)
}

/// Create a close frame
pub fn create_close_frame(code: u16, reason: &str) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(&code.to_be_bytes());
    payload.extend_from_slice(reason.as_bytes());
    create_frame(OpCode::Close, &payload, true, false)
}

/// Create a ping frame
pub fn create_ping_frame(data: &[u8]) -> Vec<u8> {
    create_frame(OpCode::Ping, data, true, false)
}

/// Create a pong frame
pub fn create_pong_frame(data: &[u8]) -> Vec<u8> {
    create_frame(OpCode::Pong, data, true, false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_and_parse_text_frame() {
        let text = "Hello, WebSocket!";
        let frame_data = create_text_frame(text);

        let (parsed_frame, consumed) = parse_frame(&frame_data).unwrap();
        assert!(parsed_frame.is_some());

        let frame = parsed_frame.unwrap();
        assert_eq!(frame.opcode, OpCode::Text);
        assert!(frame.fin);
        assert_eq!(frame.text_payload().unwrap(), text);
        assert_eq!(consumed, frame_data.len());
    }

    #[test]
    fn test_create_and_parse_close_frame() {
        let code = 1000;
        let reason = "Normal closure";
        let frame_data = create_close_frame(code, reason);

        let (parsed_frame, consumed) = parse_frame(&frame_data).unwrap();
        assert!(parsed_frame.is_some());

        let frame = parsed_frame.unwrap();
        assert_eq!(frame.opcode, OpCode::Close);
        assert!(frame.fin);

        let (parsed_code, parsed_reason) = frame.close_info();
        assert_eq!(parsed_code, code);
        assert_eq!(parsed_reason, reason);
        assert_eq!(consumed, frame_data.len());
    }

    #[test]
    fn test_invalid_opcode() {
        let data = [0x8F, 0x00]; // Invalid opcode 0x0F
        let result = parse_frame(&data);
        assert!(result.is_err());
    }

    #[test]
    fn test_incomplete_frame() {
        let data = [0x81]; // Only first byte
        let (frame, consumed) = parse_frame(&data).unwrap();
        assert!(frame.is_none());
        assert_eq!(consumed, 0);
    }
}