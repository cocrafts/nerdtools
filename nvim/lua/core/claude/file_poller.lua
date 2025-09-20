--- File-based command poller for Claude IDE
--- Polls a command file written by the Rust server
--- @module 'core.claude.file_poller'

local M = {}

local state = {
	timer = nil,
	command_file = vim.fn.expand("~/.claude/ide/commands.json"),
	last_processed = 0,
}

-- Process a command
local function process_command(command)
	if command.type == "openFile" then
		vim.schedule(function()
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

				vim.notify(
					string.format("Opened: %s", vim.fn.fnamemodify(file_path, ":~:.")),
					vim.log.levels.INFO
				)
			end
		end)
	end
end

-- Poll for commands
local function poll()
	-- Check if file exists
	if vim.fn.filereadable(state.command_file) == 0 then
		return
	end

	-- Read commands
	local ok, content = pcall(vim.fn.readfile, state.command_file)
	if not ok or #content == 0 then
		return
	end

	local json_str = table.concat(content, "\n")
	local commands_ok, commands = pcall(vim.json.decode, json_str)
	if not commands_ok or not commands then
		return
	end

	-- Process new commands
	for _, command in ipairs(commands) do
		if command.id and command.id > state.last_processed then
			process_command(command)
			state.last_processed = command.id
		end
	end

	-- Clear the file after processing
	vim.fn.writefile({}, state.command_file)
end

-- Start polling
function M.start()
	if state.timer then
		return
	end

	-- Ensure directory exists
	vim.fn.mkdir(vim.fn.expand("~/.claude/ide"), "p")

	-- Clear any existing commands
	vim.fn.writefile({}, state.command_file)

	state.timer = vim.loop.new_timer()
	state.timer:start(
		100,
		300, -- Poll every 300ms
		vim.schedule_wrap(poll)
	)

	vim.notify("Claude IDE file poller started", vim.log.levels.DEBUG)
end

-- Stop polling
function M.stop()
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end
end

return M