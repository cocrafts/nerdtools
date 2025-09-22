---@brief MCP (Model Context Protocol) handler
---@module 'plugins.claude.protocol'

local M = {}

local logger = require("plugins.claude.logger")
local tools = require("plugins.claude.tools")

--- MCP protocol version
local MCP_VERSION = "2024-11-05"

--- Handle JSON-RPC message
---@param message table
---@return table|nil response
function M.handle_message(message)
    if not message.jsonrpc or message.jsonrpc ~= "2.0" then
        return M.create_error_response(message.id, -32700, "Parse error", "Invalid JSON-RPC")
    end

    -- Handle requests (have id)
    if message.id then
        return M.handle_request(message)
    end

    -- Handle notifications (no id)
    if message.method then
        M.handle_notification(message)
        return nil -- No response for notifications
    end

    return nil
end

--- Handle JSON-RPC request
---@param message table
---@return table response
function M.handle_request(message)
    local method = message.method
    local params = message.params or {}
    local id = message.id

    logger.debug("Handling request: " .. method)

    -- Route to appropriate handler
    if method == "initialize" then
        return M.handle_initialize(id, params)
    elseif method == "tools/list" then
        return M.handle_tools_list(id, params)
    elseif method == "tools/call" then
        return M.handle_tools_call(id, params)
    elseif method == "prompts/list" then
        return M.handle_prompts_list(id, params)
    elseif method == "resources/list" then
        return M.handle_resources_list(id, params)
    elseif method == "resources/read" then
        return M.handle_resources_read(id, params)
    else
        return M.create_error_response(id, -32601, "Method not found", method)
    end
end

--- Handle JSON-RPC notification
---@param message table
function M.handle_notification(message)
    local method = message.method
    local params = message.params or {}

    logger.debug("Handling notification: " .. method)

    if method == "notifications/initialized" then
        logger.info("Client initialized")
    else
        logger.debug("Unknown notification: " .. method)
    end
end

--- Handle initialize request
---@param id any
---@param params table
---@return table
function M.handle_initialize(id, params)
    local client_version = params.protocolVersion or MCP_VERSION

    return {
        jsonrpc = "2.0",
        id = id,
        result = {
            protocolVersion = client_version,
            capabilities = {
                tools = { listChanged = true },
                resources = { subscribe = true, listChanged = true },
                prompts = { listChanged = true },
                logging = vim.empty_dict(),
            },
            serverInfo = {
                name = "claude-neovim",
                version = "0.1.0",
            },
        },
    }
end

--- Handle tools/list request
---@param id any
---@param params table
---@return table
function M.handle_tools_list(id, params)
    local tool_list = tools.get_tool_list()

    return {
        jsonrpc = "2.0",
        id = id,
        result = {
            tools = tool_list,
        },
    }
end

--- Handle tools/call request
---@param id any
---@param params table
---@return table
function M.handle_tools_call(id, params)
    local tool_name = params.name
    local tool_args = params.arguments or {}

    logger.debug("Calling tool: " .. tool_name)

    -- Execute tool
    local success, result = tools.execute(tool_name, tool_args)

    if success then
        return {
            jsonrpc = "2.0",
            id = id,
            result = result,
        }
    else
        return M.create_error_response(id, -32000, "Tool execution failed", result)
    end
end

--- Handle prompts/list request
---@param id any
---@param params table
---@return table
function M.handle_prompts_list(id, params)
    return {
        jsonrpc = "2.0",
        id = id,
        result = {
            prompts = {}, -- Empty for now
        },
    }
end

--- Handle resources/list request
---@param id any
---@param params table
---@return table
function M.handle_resources_list(id, params)
    return {
        jsonrpc = "2.0",
        id = id,
        result = {
            resources = {}, -- Empty for now
        },
    }
end

--- Handle resources/read request
---@param id any
---@param params table
---@return table
function M.handle_resources_read(id, params)
    return M.create_error_response(id, -32000, "Resources not implemented")
end

--- Create error response
---@param id any
---@param code number
---@param message string
---@param data any|nil
---@return table
function M.create_error_response(id, code, message, data)
    local error_obj = {
        code = code,
        message = message,
    }

    if data then
        error_obj.data = data
    end

    return {
        jsonrpc = "2.0",
        id = id,
        error = error_obj,
    }
end

--- Send initialized event after connection
---@param client any
function M.send_initialized_event(client)
    -- This would be sent after successful handshake
    -- For now, just log it
    logger.debug("Would send initialized event")
end

--- Create notification message
---@param method string
---@param params table|nil
---@return table
function M.create_notification(method, params)
    return {
        jsonrpc = "2.0",
        method = method,
        params = params or vim.empty_dict(),
    }
end

return M