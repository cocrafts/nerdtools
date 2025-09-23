---@brief MCP (Model Context Protocol) handler
---@module 'plugins.claude.protocol'

local M = {}

local tools = require("plugins.claude.tools")

--- MCP protocol version
local MCP_VERSION = "2024-11-05"

-- Command queue for storing tools/call requests from Claude
local command_queue = {}

-- Store pending responses for blocking operations (like openDiff)
M.pending_responses = {}

--- Handle JSON-RPC message
---@param message table
---@param client_id string|nil
---@return table|nil response
function M.handle_message(message, client_id)
    if not message.jsonrpc or message.jsonrpc ~= "2.0" then
        return M.create_error_response(message.id, -32700, "Parse error", "Invalid JSON-RPC")
    end

    -- Log all incoming methods for debugging
    if message.method then
        vim.schedule(function()
            -- Received method

            -- Special logging for tools/call
            if message.method == "tools/call" and message.params then
                vim.notify(
                    string.format("[Claude IDE] Tool call: %s", message.params.name or "unknown"),
                    vim.log.levels.INFO
                )
                -- Log the full params for openFile
                if message.params.name == "openFile" then
                    vim.notify("[Claude IDE] OpenFile params: " .. vim.inspect(message.params.arguments), vim.log.levels.INFO)
                end
            end
        end)
    end

    -- Handle requests (have id)
    if message.id then
        return M.handle_request(message, client_id)
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
---@param client_id string|nil
---@return table response
function M.handle_request(message, client_id)
    local method = message.method
    local params = message.params or {}
    local id = message.id

    -- Handling request

    -- Route to appropriate handler
    if method == "initialize" then
        return M.handle_initialize(id, params)
    elseif method == "tools/list" then
        return M.handle_tools_list(id, params)
    elseif method == "tools/call" then
        return M.handle_tools_call(id, params, client_id)
    elseif method == "poll_commands" then
        return M.handle_poll_commands(id, params)
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
    -- Currently no notifications require action
    -- This function exists for protocol completeness
    -- Claude Code may send "initialized" notifications which we can safely ignore
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
---@param client_id string|nil
---@return table
function M.handle_tools_call(id, params, client_id)
    if not params or not params.name then
        return M.create_error_response(id, -32602, "Invalid params", "Missing tool name")
    end

    local tool_name = params.name
    local tool_args = params.arguments or {}

    -- Calling tool

    -- Check if tools module is available
    if not tools or not tools.execute then
        -- Tools module error
        return M.create_error_response(id, -32500, "Internal error", "Tools module not available")
    end

    -- Special handling for openDiff - it's a blocking operation
    if tool_name == "openDiff" then
        -- OpenDiff blocking, storing response

        -- Store the message ID and client info for deferred response
        M.pending_responses[tool_args.tab_name or "default"] = {
            id = id,
            client_id = client_id,
            tab_name = tool_args.tab_name
        }

        -- Execute openDiff (it will return immediately but set up callbacks)
        local ok, success, result = pcall(tools.execute, tool_name, tool_args)

        if not ok then
            M.pending_responses[tool_args.tab_name or "default"] = nil
            return M.create_error_response(id, -32603, "Internal error", tostring(success))
        end

        if not success then
            M.pending_responses[tool_args.tab_name or "default"] = nil
            return M.create_error_response(id, -32000, "Tool execution failed", result)
        end

        -- Don't send response yet - it will be sent when user accepts/rejects
        vim.notify("[Claude IDE] OpenDiff deferred - waiting for user decision", vim.log.levels.INFO)
        return nil  -- Return nil to prevent immediate response
    end

    -- Execute other tools normally
    local ok, success, result = pcall(tools.execute, tool_name, tool_args)

    if not ok then
        -- Error calling tools.execute
        -- Error executing tool
        return M.create_error_response(id, -32603, "Internal error", tostring(success))
    end

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

--- Handle poll_commands request (for retrieving queued commands)
---@param id any
---@param params table
---@return table
function M.handle_poll_commands(id, params)
    -- Retrieve and clear the command queue
    local commands = vim.deepcopy(command_queue)
    command_queue = {}  -- Clear the queue

    if #commands > 0 then
        vim.schedule(function()
            vim.notify(
                string.format("[Claude IDE] Sending %d queued commands", #commands),
                vim.log.levels.DEBUG
            )
        end)
    end

    return {
        jsonrpc = "2.0",
        id = id,
        result = {
            commands = commands
        },
    }
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
    -- Would send initialized event
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

--- Send deferred response for openDiff
---@param tab_name string
---@param decision "accepted"|"rejected"
---@param content string|nil
function M.send_diff_response(tab_name, decision, content)
    local pending = M.pending_responses[tab_name]
    if not pending then
        -- No pending response for tab
        return
    end

    vim.notify(string.format("[Claude IDE] Sending deferred response: %s - %s", decision, tab_name), vim.log.levels.WARN)

    -- Create the response based on decision
    local response_content
    if decision == "accepted" then
        response_content = {
            content = {
                { type = "text", text = "FILE_SAVED" },
                { type = "text", text = content or "" }
            }
        }
    else
        response_content = {
            content = {
                { type = "text", text = "DIFF_REJECTED" },
                { type = "text", text = tab_name }
            }
        }
    end

    -- Build the full response
    local response = {
        jsonrpc = "2.0",
        id = pending.id,
        result = response_content
    }

    -- Send the response to the specific client
    local server = require("plugins.claude.server")
    if pending.client_id then
        server.send_to_client(pending.client_id, response)
        vim.notify(string.format("[Claude IDE] Sent deferred response to client: %s", pending.client_id), vim.log.levels.INFO)
    else
        -- Fallback to broadcast if no client_id stored
        server.broadcast(response)
        vim.notify("[Claude IDE] Broadcasted deferred response (no specific client)", vim.log.levels.WARN)
    end

    -- Clear the pending response
    M.pending_responses[tab_name] = nil
    -- Deferred response sent
end

return M