--- Session management for multiple Neovim/Claude Code pairs
--- @module 'core.claude.sessions'

local M = {}

-- List all active IDE sessions
function M.list()
	local sessions = {}
	local lock_dir = vim.fn.expand("~/.claude/ide")

	if vim.fn.isdirectory(lock_dir) == 0 then
		return sessions
	end

	-- Read all lock files
	local lock_files = vim.fn.glob(lock_dir .. "/*.lock", false, true)
	for _, lock_file in ipairs(lock_files) do
		local port = vim.fn.fnamemodify(lock_file, ":t:r")
		local content = vim.fn.readfile(lock_file)
		if #content > 0 then
			local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
			if ok and data then
				table.insert(sessions, {
					port = tonumber(port),
					pid = data.pid,
					workspace = data.workspaceFolders and data.workspaceFolders[1] or "unknown",
					auth = data.authToken and string.sub(data.authToken, 1, 8) .. "..." or "none",
					current = tonumber(port) == require("core.claude.websocket").get_info().port
				})
			end
		end
	end

	-- Sort by port
	table.sort(sessions, function(a, b) return a.port < b.port end)
	return sessions
end

-- Display all sessions in a floating window
function M.show()
	local sessions = M.list()

	if #sessions == 0 then
		vim.notify("No active Claude IDE sessions", vim.log.levels.INFO)
		return
	end

	local lines = {"=== Claude IDE Sessions ===", ""}
	local current_port = require("core.claude.websocket").get_info().port

	for _, session in ipairs(sessions) do
		local marker = session.current and " [*CURRENT*]" or ""
		local line = string.format(
			"Port %d | PID %d | %s%s",
			session.port,
			session.pid,
			vim.fn.fnamemodify(session.workspace, ":t"),
			marker
		)
		table.insert(lines, line)
	end

	table.insert(lines, "")
	table.insert(lines, "Commands:")
	table.insert(lines, ":ClaudeConnect <port> - Connect Claude Code to specific session")
	table.insert(lines, ":ClaudeLaunch <port>  - Launch Claude with specific port")
	table.insert(lines, "Current $CLAUDE_CODE_SSE_PORT: " .. (vim.env.CLAUDE_CODE_SSE_PORT or "not set"))

	-- Create floating window
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end

	local opts = {
		relative = "editor",
		width = math.min(width + 4, 80),
		height = #lines,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - #lines) / 2),
		style = "minimal",
		border = "rounded",
	}

	vim.api.nvim_open_win(buf, true, opts)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	-- Keymaps to close
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { silent = true })
end

-- Create command to connect Claude Code to specific session
function M.connect_to(port)
	if not port then
		vim.notify("Usage: :ClaudeConnect <port>", vim.log.levels.ERROR)
		return
	end

	-- Check if the port has a lock file
	local lock_file = vim.fn.expand("~/.claude/ide/" .. port .. ".lock")
	if vim.fn.filereadable(lock_file) == 0 then
		vim.notify("No session found on port " .. port, vim.log.levels.ERROR)
		return
	end

	-- Set environment variable
	vim.fn.setenv("CLAUDE_CODE_SSE_PORT", tostring(port))
	vim.notify(
		string.format(
			"Set CLAUDE_CODE_SSE_PORT=%d\nNew terminals will connect to this session",
			port
		),
		vim.log.levels.INFO
	)
end

-- Launch Claude Code with specific port
function M.launch_with_port(port)
	if not port then
		-- Use current session's port
		port = require("core.claude.websocket").get_info().port
		if not port then
			vim.notify("No active IDE session", vim.log.levels.ERROR)
			return
		end
	end

	-- Create a script to launch Claude with the right environment
	local script = string.format([[
#!/bin/bash
export CLAUDE_CODE_SSE_PORT=%d
echo "Launching Claude Code connected to Neovim on port $CLAUDE_CODE_SSE_PORT"
claude
]], port)

	local script_file = "/tmp/claude-launch-" .. port .. ".sh"
	vim.fn.writefile(vim.split(script, "\n"), script_file)
	vim.fn.system("chmod +x " .. script_file)

	-- Open in terminal based on OS
	local cmd
	if vim.fn.has("mac") == 1 then
		cmd = "open -a Terminal " .. script_file
	else
		cmd = "x-terminal-emulator -e " .. script_file .. " &"
	end

	vim.fn.system(cmd)
	vim.notify("Launching Claude Code for port " .. port, vim.log.levels.INFO)
end

-- Setup commands
function M.setup()
	vim.api.nvim_create_user_command("ClaudeSessions", M.show, {
		desc = "Show all Claude IDE sessions",
	})

	vim.api.nvim_create_user_command("ClaudeConnect", function(opts)
		local port = tonumber(opts.args)
		M.connect_to(port)
	end, {
		nargs = 1,
		desc = "Connect Claude Code to specific session",
	})

	vim.api.nvim_create_user_command("ClaudeLaunch", function(opts)
		local port = tonumber(opts.args)
		M.launch_with_port(port)
	end, {
		nargs = "?",
		desc = "Launch Claude Code with specific port",
	})
end

return M