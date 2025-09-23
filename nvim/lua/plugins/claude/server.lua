---@brief TCP/WebSocket server implementation for Claude IDE
---@module 'plugins.claude.server'

local M = {}

local frame = require("plugins.claude.frame")
local handshake = require("plugins.claude.handshake")
local lockfile = require("plugins.claude.lockfile")
local protocol = require("plugins.claude.protocol")

-- Server state
local state = {
	server = nil,
	port = nil,
	auth_token = nil,
	clients = {},
	running = false,
}

--- Generate a deterministic port based on workspace path
---@param workspace string
---@param min_port number
---@param max_port number
---@return number
local function workspace_to_port(workspace, min_port, max_port)
	-- Simple hash function for string
	local hash = 0
	for i = 1, #workspace do
		hash = (hash * 31 + workspace:byte(i)) % 2147483647
	end

	-- Map hash to port range
	local port_range = max_port - min_port + 1
	return min_port + (hash % port_range)
end

--- Find available port in range
---@param min_port number
---@param max_port number
---@param preferred_port number|nil Optional preferred port to try first
---@return number|nil port
local function find_available_port(min_port, max_port, preferred_port)
	-- Try preferred port first if provided
	if preferred_port and preferred_port >= min_port and preferred_port <= max_port then
		local tcp = vim.loop.new_tcp()
		if tcp then
			local success = tcp:bind("127.0.0.1", preferred_port)
			tcp:close()
			if success then
				return preferred_port
			end
		end
	end

	for _ = 1, 100 do -- Try random ports
		local port = math.random(min_port, max_port)
		local tcp = vim.loop.new_tcp()

		if tcp then
			local success = tcp:bind("127.0.0.1", port)
			tcp:close()

			if success then
				return port
			end
		end
	end

	-- Fallback to sequential search
	for port = min_port, max_port do
		local tcp = vim.loop.new_tcp()
		if tcp then
			local success = tcp:bind("127.0.0.1", port)
			tcp:close()

			if success then
				return port
			end
		end
	end

	return nil
end

--- Handle client connection
---@param client table TCP client handle
local function handle_client(client)
	local client_id = tostring(client)

	state.clients[client_id] = {
		tcp = client,
		buffer = "",
		handshake_complete = false,
		is_websocket = false,
	}

	-- Client connection logged

	client:read_start(function(err, data)
		if err then
			-- Read error logged
			M.disconnect_client(client_id)
			return
		end

		if not data then
			-- Connection closed
			M.disconnect_client(client_id)
			return
		end

		local client_data = state.clients[client_id]
		if not client_data then
			return
		end

		client_data.buffer = client_data.buffer .. data

		-- Handle WebSocket handshake if not complete
		if not client_data.handshake_complete then
			local complete, request, remaining = handshake.extract_http_request(client_data.buffer)

			if complete then
				client_data.buffer = remaining or ""

				-- Process handshake
				local success, response, headers = handshake.process_handshake(request, state.auth_token)

				if success then
					client:write(response)
					client_data.handshake_complete = true
					client_data.is_websocket = true
					-- Handshake complete
				else
					-- Log the error
					-- Handshake failed
					-- Send error and close
					client:write(response)
					vim.defer_fn(function()
						M.disconnect_client(client_id)
					end, 100)
				end
			end
		else
			-- Handle WebSocket frames
			M.process_websocket_data(client_id)
		end
	end)
end

--- Process WebSocket data from client
---@param client_id string
function M.process_websocket_data(client_id)
	local client_data = state.clients[client_id]
	if not client_data then
		return
	end

	while #client_data.buffer > 0 do
		local frame_data, remaining = frame.decode(client_data.buffer)

		if not frame_data then
			break -- Need more data
		end

		client_data.buffer = remaining

		-- Handle different frame types
		if frame_data.opcode == frame.OPCODE.TEXT then
			-- Parse JSON-RPC message
			local ok, message = pcall(vim.json.decode, frame_data.payload)
			if ok then
				M.handle_message(client_id, message)
			else
				-- JSON parse error
			end
		elseif frame_data.opcode == frame.OPCODE.CLOSE then
			-- Close connection
			M.disconnect_client(client_id)
		elseif frame_data.opcode == frame.OPCODE.PING then
			-- Send pong
			local pong = frame.encode({
				fin = true,
				opcode = frame.OPCODE.PONG,
				payload = frame_data.payload or "",
			})
			client_data.tcp:write(pong)
		end
	end
end

--- Handle JSON-RPC message from client
---@param client_id string
---@param message table
function M.handle_message(client_id, message)
	-- Debug logging removed

	-- Schedule handling in main thread to avoid fast event context issues
	vim.schedule(function()
		-- Debug logging removed

		-- Tool call logging removed

		-- Notification logging removed
		-- Handle message with error protection (pass client_id for deferred responses)
		local ok, response = pcall(protocol.handle_message, message, client_id)

		if not ok then
			-- Message handling error
			-- Send error response if we have a message id
			if message.id then
				local error_response = {
					jsonrpc = "2.0",
					id = message.id,
					error = {
						code = -32603,
						message = "Internal error",
						data = tostring(response),
					},
				}
				M.send_to_client(client_id, error_response)
			end
			return
		end

		if response then
			-- Sending MCP response
			M.send_to_client(client_id, response)
		end
	end)
end

--- Send message to specific client
---@param client_id string
---@param message table
---@return boolean success
function M.send_to_client(client_id, message)
	local client_data = state.clients[client_id]
	if not client_data or not client_data.tcp then
		-- Invalid client data
		return false
	end

	local json = vim.json.encode(message)
	-- Sending to client

	if client_data.is_websocket then
		-- Wrap in WebSocket frame
		local frame_data = frame.encode({
			fin = true,
			opcode = frame.OPCODE.TEXT,
			payload = json,
		})
		local ok, err = pcall(function()
			client_data.tcp:write(frame_data)
		end)
		if not ok then
			-- Write failed
			return false
		end
		-- Frame sent
	else
		-- Plain TCP (shouldn't happen with Claude)
		client_data.tcp:write(json .. "\n")
	end
	return true
end

--- Broadcast message to all connected clients
---@param message table
function M.broadcast(message)
	-- Broadcasting message
	local count = 0
	for client_id, _ in pairs(state.clients) do
		M.send_to_client(client_id, message)
		count = count + 1
	end
	-- Broadcasted to clients
	if count == 0 then
		-- No clients connected
	end
end

--- Send at-mention notification
---@param params table
function M.send_at_mention(params)
	local message = {
		jsonrpc = "2.0",
		method = "at_mentioned",
		params = params,
	}

	M.broadcast(message)
	return true
end

--- Send selection change notification
---@param params table
function M.send_selection_changed(params)
	local message = {
		jsonrpc = "2.0",
		method = "selection_changed",
		params = params,
	}

	M.broadcast(message)
	return true
end

--- Disconnect client
---@param client_id string
function M.disconnect_client(client_id)
	local client_data = state.clients[client_id]
	if client_data then
		if client_data.tcp then
			client_data.tcp:read_stop()
			client_data.tcp:shutdown()
			client_data.tcp:close()
		end
		state.clients[client_id] = nil
		-- Client disconnected
	end
end

--- Start the WebSocket server
---@param opts table|nil
---@return boolean success
---@return number|string port_or_error
---@return string|nil auth_token
function M.start(opts)
	opts = opts or {}

	if state.running then
		return false, "Server already running"
	end

	local port, auth_token
	local workspace_auth_token = nil -- Remember auth token for workspace even if port changes

	-- Try to reuse previous port from lock files (for reconnection support)
	if opts.reuse_port ~= false then
		-- Check for existing lock files in ~/.claude/ide/
		local lock_dir = lockfile.get_lock_dir()
		local lock_files = vim.fn.glob(lock_dir .. "/*.lock", false, true)
		local current_workspace = vim.fn.getcwd()

		-- First pass: Try to find a lock file for the same workspace
		for _, lock_path in ipairs(lock_files) do
			-- Extract port from filename
			local port_str = vim.fn.fnamemodify(lock_path, ":t:r")
			local check_port = tonumber(port_str)

			if check_port then
				-- Read lock file to check workspace and process
				local lock_data = lockfile.read(check_port)

				if lock_data then
					-- Check if this is for the same workspace
					local same_workspace = false
					if lock_data.workspaceFolders then
						for _, folder in ipairs(lock_data.workspaceFolders) do
							if folder == current_workspace then
								same_workspace = true
								break
							end
						end
					end

					if same_workspace then
						-- ALWAYS preserve the auth token for the same workspace
						workspace_auth_token = lock_data.authToken
						-- Found existing auth token

						local is_running = false
						if lock_data.pid then
							-- Check if the process is still running
							is_running = vim.fn
								.system("kill -0 " .. lock_data.pid .. " 2>/dev/null; echo $?")
								:gsub("\n", "") == "0"
						end

						if not is_running then
							-- Process is dead, we can reuse this port
							-- Try to bind to verify it's actually available
							local tcp = vim.loop.new_tcp()
							if tcp then
								local success = tcp:bind("127.0.0.1", check_port)
								tcp:close()

								if success then
									port = check_port
									auth_token = workspace_auth_token
									-- Reusing port and auth token
									-- Clean up old lock file (will be recreated)
									lockfile.delete(port)
									break
								else
									-- Port unavailable, keeping auth token
								end
							end
						else
							-- Process running, keeping auth token
						end
					end
				end
			end
		end

		-- Second pass: If no workspace match, try any dead session
		if not port then
			for _, lock_path in ipairs(lock_files) do
				local port_str = vim.fn.fnamemodify(lock_path, ":t:r")
				local check_port = tonumber(port_str)

				if check_port then
					local lock_data = lockfile.read(check_port)
					if lock_data and lock_data.pid then
						local is_running = vim.fn
							.system("kill -0 " .. lock_data.pid .. " 2>/dev/null; echo $?")
							:gsub("\n", "") == "0"
						if not is_running then
							local tcp = vim.loop.new_tcp()
							if tcp then
								local success = tcp:bind("127.0.0.1", check_port)
								tcp:close()
								if success then
									port = check_port
									auth_token = lock_data.authToken
									-- Reusing port from dead session
									lockfile.delete(port)
									break
								end
							end
						end
					end
				end
			end
		end
	end

	-- If no reused port, find a new one
	if not port then
		local min_port = opts.port_min or 10000
		local max_port = opts.port_max or 65535
		local current_workspace = vim.fn.getcwd()

		-- Generate a deterministic preferred port based on workspace
		local preferred_port = workspace_to_port(current_workspace, min_port, max_port)
		-- Preferred port calculated

		port = find_available_port(min_port, max_port, preferred_port)
		if not port then
			return false, "No available port found"
		end

		if port == preferred_port then
			-- Using preferred port
		else
			-- Preferred port unavailable
		end
	end

	-- Use auth token in order of preference:
	-- 1. Reused from same port (auth_token)
	-- 2. Preserved from same workspace (workspace_auth_token)
	-- 3. Generate new one
	local auth_reused = false
	if auth_token then
		state.auth_token = auth_token
		auth_reused = true
		-- Using auth token from reused port
	elseif workspace_auth_token then
		state.auth_token = workspace_auth_token
		auth_reused = true
		-- Using preserved auth token
	else
		state.auth_token = lockfile.generate_auth_token()
		-- Generated new auth token
	end
	state.auth_reused = auth_reused

	-- Create TCP server
	state.server = vim.loop.new_tcp()
	if not state.server then
		return false, "Failed to create TCP server"
	end

	-- Bind to port
	local success, err = state.server:bind("127.0.0.1", port)
	if not success then
		state.server:close()
		state.server = nil
		return false, "Failed to bind: " .. (err or "unknown error")
	end

	-- Start listening
	state.server:listen(128, function(err)
		if err then
			-- Listen error
			return
		end

		local client = vim.loop.new_tcp()
		state.server:accept(client)
		handle_client(client)
	end)

	state.port = port
	state.running = true

	-- Create lock file
	-- Creating lock file
	local lock_success, lock_err = lockfile.create(port, state.auth_token)
	if not lock_success then
		-- Failed to create lock file
		vim.notify("Failed to create Claude IDE lock file: " .. (lock_err or "unknown error"), vim.log.levels.ERROR)
	else
		-- Lock file created
		local lock_path = lockfile.get_lock_path(port)
		-- Check if we're reusing auth token
		if state.auth_reused then
			vim.notify("Claude IDE: Reusing auth token for reconnection on port " .. port, vim.log.levels.INFO)
			vim.notify("Claude Code should auto-reconnect with same credentials", vim.log.levels.INFO)
		else
			vim.notify("Claude IDE lock file created: " .. lock_path, vim.log.levels.INFO)
		end
	end

	-- WebSocket server started

	-- Start ping timer to keep connections alive
	M.start_ping_timer()

	return true, port, state.auth_token
end

--- Start ping timer
function M.start_ping_timer()
	if state.ping_timer then
		state.ping_timer:stop()
		state.ping_timer:close()
	end

	state.ping_timer = vim.loop.new_timer()
	state.ping_timer:start(30000, 30000, function()
		vim.schedule(function()
			for client_id, client_data in pairs(state.clients) do
				if client_data.is_websocket then
					local ping_frame = frame.encode({
						fin = true,
						opcode = frame.OPCODE.PING,
						payload = "",
					})

					local ok = pcall(function()
						client_data.tcp:write(ping_frame)
					end)

					if not ok then
						M.disconnect_client(client_id)
					end
				end
			end
		end)
	end)
end

--- Stop the server
function M.stop()
	state.running = false

	if state.ping_timer then
		state.ping_timer:stop()
		state.ping_timer:close()
		state.ping_timer = nil
	end

	-- Disconnect all clients
	for client_id, _ in pairs(state.clients) do
		M.disconnect_client(client_id)
	end

	if state.server then
		state.server:close()
		state.server = nil
	end

	if state.port then
		lockfile.remove(state.port)
		state.port = nil
	end

	state.auth_token = nil

	-- Server stopped
end

--- Check if connected
---@return boolean
function M.is_connected()
	return next(state.clients) ~= nil
end

--- Get client count
---@return number
function M.get_client_count()
	local count = 0
	for _ in pairs(state.clients) do
		count = count + 1
	end
	return count
end

--- Get server info
---@return table
function M.get_info()
	return {
		running = state.running,
		port = state.port,
		client_count = M.get_client_count(),
		clients = vim.tbl_keys(state.clients),
	}
end

return M
