--- Simple TCP client for Neovim to communicate with Claude IDE server
--- Uses vim.loop (libuv) for TCP connection
--- @module 'core.claude.tcp_client'

local M = {}

local state = {
	tcp = nil,
	connected = false,
	port = nil,
	poll_timer = nil,
}

-- Process commands from server
local function process_command(cmd)
	-- Only show this in debug mode if needed
	-- vim.notify(string.format("Processing command: %s", vim.inspect(cmd)), vim.log.levels.DEBUG)

	if cmd.type == "openFile" then
		vim.schedule(function()
			vim.notify(string.format("Opening file: %s", cmd.filePath), vim.log.levels.INFO)
			vim.cmd.edit(cmd.filePath)
			if cmd.startLine then
				-- Move to start line
				vim.fn.cursor(cmd.startLine, 1)

				if cmd.endLine and cmd.endLine > cmd.startLine then
					-- Use feedkeys for visual selection to work properly
					local keys = vim.api.nvim_replace_termcodes(
						string.format("V%dG", cmd.endLine),
						true, false, true
					)
					vim.api.nvim_feedkeys(keys, 'n', false)

					-- Leave in visual mode so user can see the selection
					vim.notify(string.format("Selected lines %d-%d", cmd.startLine, cmd.endLine), vim.log.levels.INFO)
				end
			end
			vim.notify(string.format("Opened: %s", vim.fn.fnamemodify(cmd.filePath, ":~:.")), vim.log.levels.INFO)
		end)
	elseif cmd.type == "openDiff" then
		-- TODO: Implement diff
		vim.notify("openDiff not yet implemented", vim.log.levels.WARN)
	else
		vim.notify(string.format("Unknown command type: %s", cmd.type or "nil"), vim.log.levels.WARN)
	end
end

-- Handle data from server
local function handle_data(data)
	-- Parse JSON response
	local ok, response = pcall(vim.json.decode, data)
	if not ok then
		vim.notify(string.format("Failed to parse JSON: %s", data), vim.log.levels.ERROR)
		return
	end

	-- Handle command responses
	if response.type == "commands" and response.commands then
		-- Only notify if there are actually commands
		if #response.commands > 0 then
			vim.notify(string.format("Got %d commands", #response.commands), vim.log.levels.INFO)
		end
		for _, cmd in ipairs(response.commands) do
			process_command(cmd)
		end
	elseif response.status == "connected" then
		vim.notify("Connected to Claude IDE TCP server", vim.log.levels.DEBUG)
	else
		-- Silent for unknown responses unless they're errors
		if response.error then
			vim.notify(string.format("Error response: %s", vim.inspect(response)), vim.log.levels.WARN)
		end
	end
end

-- Send a message to the server
local function send_message(msg)
	if not state.tcp or not state.connected then
		return false
	end

	local json = vim.json.encode(msg) .. "\n"
	state.tcp:write(json)
	return true
end

-- Poll for commands
local function poll_commands()
	send_message({ method = "poll" })
end

-- Connect to TCP server
function M.connect()
	-- Read lock file to get Neovim port
	local lock_dir = vim.fn.expand("~/.claude/ide")
	local lock_files = vim.fn.glob(lock_dir .. "/*.lock", false, true)
	if #lock_files == 0 then
		vim.notify("No Claude IDE server found", vim.log.levels.WARN)
		return false
	end

	-- Read first lock file
	local lock_file = lock_files[1]
	local content = vim.fn.readfile(lock_file)
	if #content == 0 then
		return false
	end

	local ok, lock_data = pcall(vim.json.decode, table.concat(content, "\n"))
	if not ok or not lock_data.neovimPort then
		vim.notify("No Neovim port in lock file", vim.log.levels.WARN)
		return false
	end

	state.port = lock_data.neovimPort

	-- Create TCP client
	state.tcp = vim.loop.new_tcp()

	-- Connect to server
	state.tcp:connect("127.0.0.1", state.port, function(err)
		if err then
			vim.notify("Failed to connect to Claude IDE: " .. err, vim.log.levels.ERROR)
			return
		end

		state.connected = true
		vim.notify("Connected to Claude IDE on port " .. state.port, vim.log.levels.INFO)

		-- Send ready message
		vim.schedule(function()
			send_message({ method = "ready" })
		end)

		-- Start reading data
		state.tcp:read_start(function(read_err, chunk)
			if read_err then
				vim.notify("TCP read error: " .. read_err, vim.log.levels.ERROR)
				M.disconnect()
				return
			end

			if chunk then
				-- Buffer management for potentially partial messages
				local lines = vim.split(chunk, "\n")
				for _, line in ipairs(lines) do
					if line ~= "" then
						handle_data(line)
					end
				end
			else
				-- Connection closed
				M.disconnect()
			end
		end)

		-- Start polling timer
		if not state.poll_timer then
			state.poll_timer = vim.loop.new_timer()
			state.poll_timer:start(
				500, -- Initial delay
				300, -- Repeat every 300ms
				vim.schedule_wrap(poll_commands)
			)
		end
	end)

	return true
end

-- Disconnect from server
function M.disconnect()
	if state.poll_timer then
		state.poll_timer:stop()
		state.poll_timer:close()
		state.poll_timer = nil
	end

	if state.tcp then
		state.tcp:read_stop()
		state.tcp:shutdown()
		state.tcp:close()
		state.tcp = nil
	end

	state.connected = false
	vim.notify("Disconnected from Claude IDE", vim.log.levels.INFO)
end

-- Send selection update
function M.send_selection(file_path, text, start_line, start_char, end_line, end_char)
	return send_message({
		method = "selection",
		data = {
			filePath = file_path,
			text = text,
			startLine = start_line,
			startChar = start_char,
			endLine = end_line,
			endChar = end_char,
		},
	})
end

-- Send diagnostics
function M.send_diagnostics(diagnostics)
	return send_message({
		method = "diagnostics",
		data = diagnostics,
	})
end

-- Check if connected
function M.is_connected()
	return state.connected
end

return M