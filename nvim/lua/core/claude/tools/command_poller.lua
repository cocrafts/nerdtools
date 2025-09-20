--- Command poller for Claude IDE bidirectional communication
--- Polls the Rust server for pending commands and executes them
--- @module 'core.claude.tools.command_poller'

local M = {}

-- Poller state
local state = {
	timer = nil,
	polling = false,
	poll_interval_ms = 500, -- Poll every 500ms
}

-- Import websocket for communication
local websocket = require("core.claude.websocket")

-- Handle openFile command
local function handle_open_file(command)
	local file_path = command.filePath
	if not file_path then
		vim.notify("openFile: Missing filePath", vim.log.levels.WARN)
		return
	end

	-- Open the file
	vim.schedule(function()
		vim.cmd.edit(file_path)

		-- Handle line ranges if provided
		local start_line = command.startLine
		local end_line = command.endLine

		if start_line then
			-- Move cursor to start line
			vim.fn.cursor(start_line, 1)

			if end_line and end_line > start_line then
				-- Select the range in visual line mode
				vim.cmd("normal! V")
				vim.fn.cursor(end_line, 1)
				-- Brief pause in visual mode to show selection
				vim.defer_fn(function()
					vim.cmd("normal! <Esc>")
				end, 100)
			end
		end

		vim.notify(string.format("Opened: %s", vim.fn.fnamemodify(file_path, ":~:.")), vim.log.levels.INFO)
	end)
end

-- Handle different command types
local function handle_command(command)
	if not command or not command.type then
		return
	end

	local command_type = command.type

	if command_type == "openFile" then
		handle_open_file(command)
	elseif command_type == "openDiff" then
		-- TODO: Implement diff handling
		vim.notify("openDiff not yet implemented", vim.log.levels.WARN)
	elseif command_type == "saveFile" then
		-- TODO: Implement save handling
		vim.notify("saveFile not yet implemented", vim.log.levels.WARN)
	else
		vim.notify(string.format("Unknown command type: %s", command_type), vim.log.levels.WARN)
	end
end

-- Poll for commands
local function poll_commands()
	if state.polling then
		return -- Already polling
	end

	state.polling = true

	-- Send poll_commands request to the server
	local job_id = websocket.get_info().job_id
	if not job_id then
		state.polling = false
		return
	end

	-- Send poll request
	local request = vim.json.encode({
		method = "poll_commands",
	})

	vim.fn.chansend(job_id, request .. "\n")

	-- Wait for response (simplified synchronous approach)
	vim.defer_fn(function()
		-- The response will be captured by websocket's stdout handler
		-- For now, we'll use a simple approach with a temporary file
		local temp_file = "/tmp/claude_commands_response.json"

		-- Try to read the response (if websocket saved it)
		local ok, content = pcall(vim.fn.readfile, temp_file)
		if ok and #content > 0 then
			local response_text = table.concat(content, "\n")
			local response_ok, response = pcall(vim.json.decode, response_text)

			if response_ok and response and response.success and response.commands then
				-- Process each command
				for _, command in ipairs(response.commands) do
					handle_command(command)
				end

				-- Clear the temp file
				vim.fn.delete(temp_file)
			end
		end

		state.polling = false
	end, 100)
end

-- Start polling for commands
function M.start()
	if state.timer then
		return -- Already running
	end

	-- Create timer for periodic polling
	state.timer = vim.loop.new_timer()
	state.timer:start(
		1000, -- Initial delay
		state.poll_interval_ms,
		vim.schedule_wrap(function()
			poll_commands()
		end)
	)

	vim.notify("Claude IDE command poller started", vim.log.levels.DEBUG)
end

-- Stop polling
function M.stop()
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end

	state.polling = false
	vim.notify("Claude IDE command poller stopped", vim.log.levels.DEBUG)
end

-- Check if polling is active
function M.is_running()
	return state.timer ~= nil
end

-- Manual poll (for testing)
function M.poll_once()
	poll_commands()
end

return M