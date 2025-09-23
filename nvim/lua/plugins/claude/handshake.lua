---@brief WebSocket handshake handling (RFC 6455)
---@module 'plugins.claude.handshake'

local M = {}

local utils = require("plugins.claude.utils")

--- Parse HTTP headers
---@param request string
---@return table
local function parse_headers(request)
    return utils.parse_http_headers(request)
end

--- Validate WebSocket upgrade request
---@param request string
---@param expected_auth_token string|nil
---@return boolean valid
---@return table|string headers_or_error
function M.validate_upgrade_request(request, expected_auth_token)
    local headers = parse_headers(request)

    -- Check required headers
    if not headers["upgrade"] or headers["upgrade"]:lower() ~= "websocket" then
        return false, "Missing or invalid Upgrade header"
    end

    if not headers["connection"] or not headers["connection"]:lower():find("upgrade") then
        return false, "Missing or invalid Connection header"
    end

    if not headers["sec-websocket-key"] then
        return false, "Missing Sec-WebSocket-Key header"
    end

    if not headers["sec-websocket-version"] or headers["sec-websocket-version"] ~= "13" then
        return false, "Missing or unsupported Sec-WebSocket-Version header"
    end

    -- Auth token validation (optional for local connections)
    -- Claude Code doesn't send auth headers for local connections, which is acceptable
    if expected_auth_token then
        local auth_header = headers["x-claude-code-ide-authorization"]

        -- Only reject if auth header is present but incorrect
        if auth_header and auth_header ~= expected_auth_token then
            -- Auth token mismatch
            return false, "Invalid authentication token"
        end
    end

    return true, headers
end

--- Create handshake response
---@param client_key string
---@param protocol string|nil
---@return string
function M.create_handshake_response(client_key, protocol)
    local accept_key = utils.generate_accept_key(client_key)

    local response_lines = {
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Accept: " .. accept_key,
    }

    if protocol then
        table.insert(response_lines, "Sec-WebSocket-Protocol: " .. protocol)
    end

    table.insert(response_lines, "")
    table.insert(response_lines, "")

    return table.concat(response_lines, "\r\n")
end

--- Create error response
---@param code number
---@param message string
---@return string
function M.create_error_response(code, message)
    local status_text = {
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [404] = "Not Found",
        [426] = "Upgrade Required",
        [500] = "Internal Server Error",
    }

    local status = status_text[code] or "Error"

    local response_lines = {
        "HTTP/1.1 " .. code .. " " .. status,
        "Content-Type: text/plain",
        "Content-Length: " .. #message,
        "Connection: close",
        "",
        message,
    }

    return table.concat(response_lines, "\r\n")
end

--- Check if request is for WebSocket endpoint
---@param request string
---@return boolean
function M.is_websocket_endpoint(request)
    local first_line = request:match("^([^\r\n]+)")
    if not first_line then
        return false
    end

    local method, path, version = first_line:match("^(%S+)%s+(%S+)%s+(%S+)$")

    -- Must be GET request
    if method ~= "GET" then
        return false
    end

    -- Must be HTTP/1.1
    if not version or not version:match("^HTTP/1%.1") then
        return false
    end

    return true
end

--- Process complete handshake
---@param request string
---@param expected_auth_token string|nil
---@return boolean success
---@return string response
---@return table|nil headers
function M.process_handshake(request, expected_auth_token)
    -- Check if valid WebSocket endpoint
    if not M.is_websocket_endpoint(request) then
        local response = M.create_error_response(404, "WebSocket endpoint not found")
        return false, response, nil
    end

    -- Validate upgrade request
    local is_valid, validation_result = M.validate_upgrade_request(request, expected_auth_token)
    if not is_valid then
        local error_message = validation_result
        local response = M.create_error_response(400, "Bad WebSocket upgrade request: " .. error_message)
        return false, response, nil
    end

    local headers = validation_result

    -- Generate handshake response
    local client_key = headers["sec-websocket-key"]
    local protocol = headers["sec-websocket-protocol"]

    local response = M.create_handshake_response(client_key, protocol)

    return true, response, headers
end

--- Extract complete HTTP request from buffer
---@param buffer string
---@return boolean complete
---@return string|nil request
---@return string remaining
function M.extract_http_request(buffer)
    -- Look for end of HTTP headers
    local header_end = buffer:find("\r\n\r\n")
    if not header_end then
        return false, nil, buffer
    end

    local request = buffer:sub(1, header_end + 3)
    local remaining = buffer:sub(header_end + 4)

    return true, request, remaining
end

return M