--- WebSocket server for Claude Code integration
--- Uses Nim binary for proper WebSocket implementation
--- @module 'core.claude.websocket'

local M = {}

-- Server state
local state = {
	job_id = nil,
	port = nil,
	auth_token = nil,
	connected = false,
	binary_path = nil,
	last_response = nil, -- Store last response for polling
}

-- Import utilities
local utils = require("core.claude.utils")

-- Find the claudeIde binary
local function find_binary()
	-- Check if already cached
	if state.binary_path then
		return state.binary_path
	end

	-- Look for the binary in various locations
	local paths = {
		vim.fn.expand("~/nerdtools/core/target/release/claude-ide"),
		vim.fn.expand("~/nerdtools/core/claude-ide/target/release/claude-ide"),
		vim.fn.expand("~/.local/bin/claude-ide"),
		"/usr/local/bin/claude-ide",
	}

	for _, path in ipairs(paths) do
		if vim.fn.executable(path) == 1 then
			state.binary_path = path
			return path
		end
	end

	-- If not found, try to build it
	local build_dir = vim.fn.expand("~/nerdtools/core")
	if vim.fn.isdirectory(build_dir) == 1 then
		vim.fn.system("cd " .. build_dir .. " && cargo build --release 2>/dev/null")
		local built_path = build_dir .. "/target/release/claude-ide"
		if vim.fn.executable(built_path) == 1 then
			state.binary_path = built_path
			return built_path
		end
	end

	return nil
end

-- Send JSON message to the server
local function send_command(command)
	if not state.job_id then
		return nil
	end

	local json = vim.json.encode(command)
	vim.fn.chansend(state.job_id, json .. "\n")

	-- Wait for response (simplified - in production would be async)
	vim.wait(100)

	return true
end

-- Start WebSocket server
function M.start()
	if state.job_id then
		-- Already running, return existing info
		local response = send_command({
			method = "status",
		})
		if response then
			return state.port, state.auth_token
		end
	end

	local binary = find_binary()
	if not binary then
		vim.notify("Claude IDE binary not found. Please build it first.", vim.log.levels.ERROR)
		return nil, nil
	end

	-- Get project root for accurate workspace detection
	local workspace_folder = utils.get_project_root()

	-- Start the server process in daemon mode with workspace folder
	local cmd = { binary, "daemon", workspace_folder }
	state.job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data, _)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						local ok, response = pcall(vim.json.decode, line)
						if ok and response then
							-- Store response for polling
							state.last_response = response

							if response.success then
								state.port = response.port or state.port
								state.auth_token = response.auth_token or state.auth_token
								state.connected = response.connected or state.connected

								-- Handle command responses
								if response.commands then
									-- Process commands directly here
									local command_poller = require("core.claude.tools.command_poller")
									for _, command in ipairs(response.commands) do
										vim.schedule(function()
											if command.type == "openFile" then
												local file_path = command.filePath
												if file_path then
													vim.cmd.edit(file_path)

													if command.startLine then
														vim.fn.cursor(command.startLine, 1)

														if command.endLine and command.endLine > command.startLine then
															vim.cmd("normal! V")
															vim.fn.cursor(command.endLine, 1)
															vim.defer_fn(function()
																vim.cmd("normal! <Esc>")
															end, 100)
														end
													end

													vim.notify(string.format("Opened: %s", vim.fn.fnamemodify(file_path, ":~:.")), vim.log.levels.INFO)
												end
											end
										end)
									end
								end
							end
						end
					end
				end
			end
		end,
		on_stderr = function(_, data, _)
			-- Log errors to Neovim messages
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" and not line:match("^%[") then -- Skip log messages
						vim.notify("Claude IDE: " .. line, vim.log.levels.DEBUG)
					end
				end
			end
		end,
		on_exit = function(_, code, _)
			state.job_id = nil
			state.port = nil
			state.auth_token = nil
			state.connected = false
			if code ~= 0 then
				vim.notify("Claude IDE server exited with code: " .. code, vim.log.levels.ERROR)
			end
		end,
	})

	if state.job_id == 0 or state.job_id == -1 then
		vim.notify("Failed to start Claude IDE server", vim.log.levels.ERROR)
		return nil, nil
	end

	-- Wait for daemon to start and provide connection info
	vim.wait(1000, function()
		return state.port ~= nil
	end)

	-- Set environment variable for Claude Code to find the server
	if state.port then
		vim.fn.setenv("CLAUDE_CODE_SSE_PORT", tostring(state.port))
		-- Connect to TCP server for bidirectional communication
		vim.defer_fn(function()
			require("core.claude.tcp_client").connect()
		end, 500) -- Give server time to start TCP listener
	end

	return state.port, state.auth_token
end

-- Stop server
function M.stop()
	-- Disconnect TCP client first
	require("core.claude.tcp_client").disconnect()

	if state.job_id then
		send_command({ method = "stop" })
		vim.wait(100)
		vim.fn.jobstop(state.job_id)
		state.job_id = nil
	end

	-- Clear environment variable
	vim.fn.setenv("CLAUDE_CODE_SSE_PORT", "")

	state.port = nil
	state.auth_token = nil
	state.connected = false
end

-- Send JSON-RPC message
function M.send_message(method, params)
	if not state.job_id then
		return false
	end

	return send_command({
		method = "send_message",
		params = {
			method = method,
			params = params,
		},
	})
end

-- Send at-mention
function M.send_mention(file_path, text, line_start, line_end)
	return M.send_message("at_mentioned", {
		filePath = file_path,
		text = text or "",
		lineStart = line_start,
		lineEnd = line_end,
	})
end

-- Send notification (no response expected)
function M.send_notification(method, params)
	if not state.job_id then
		return false
	end

	return send_command({
		method = "send_notification",
		params = {
			method = method,
			params = params,
		},
	})
end

-- Check connection status
function M.is_connected()
	-- Debug: Log connection status
	vim.notify("Claude IDE: Checking connection - job_id=" .. tostring(state.job_id) .. ", port=" .. tostring(state.port), vim.log.levels.INFO)

	-- If we have a running job and port/auth_token, consider it connected
	if state.job_id and state.port and state.auth_token then
		-- Check if the process is still running
		local job_exists = vim.fn.jobwait({state.job_id}, 0)[1] == -1
		if job_exists then
			vim.notify("Claude IDE: WebSocket server connected on port " .. state.port, vim.log.levels.INFO)
			return true
		else
			-- Job died, reset state
			state.job_id = nil
			state.port = nil
			state.auth_token = nil
			state.connected = false
			vim.notify("Claude IDE: WebSocket server disconnected", vim.log.levels.WARN)
		end
	else
		vim.notify("Claude IDE: No WebSocket server running", vim.log.levels.WARN)
	end
	return false
end

-- Get server info
function M.get_info()
	return {
		running = state.job_id ~= nil,
		port = state.port,
		auth_token = state.auth_token,
		connected = state.connected,
		binary_path = state.binary_path,
		mode = state.job_id and "websocket" or "fallback",
		job_id = state.job_id,
	}
end

-- Poll for commands from Claude
function M.poll_commands()
	if not state.job_id then
		return nil
	end

	-- Send poll request
	local request = vim.json.encode({
		method = "poll_commands",
	})

	vim.fn.chansend(state.job_id, request .. "\n")

	-- Commands will be processed in on_stdout handler
	return true
end

-- Start automatic polling
function M.start_polling()
	-- Create timer for periodic polling
	if not state.poll_timer then
		state.poll_timer = vim.loop.new_timer()
		state.poll_timer:start(
			1000, -- Initial delay
			500, -- Poll every 500ms
			vim.schedule_wrap(function()
				M.poll_commands()
			end)
		)
	end
end

-- Stop polling
function M.stop_polling()
	if state.poll_timer then
		state.poll_timer:stop()
		state.poll_timer:close()
		state.poll_timer = nil
	end
end

return M