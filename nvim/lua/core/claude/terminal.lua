--- Terminal integration for Claude Code
--- Handles launching Claude with proper environment variables
--- @module 'core.claude.terminal'

local M = {}

local websocket = require("core.claude.websocket")

-- Open Claude terminal with IDE environment
function M.open_claude()
	local port = websocket.get_info().port
	if not port then
		vim.notify("Claude IDE: WebSocket server not running", vim.log.levels.ERROR)
		return
	end

	-- Build the command with environment variable
	local cmd = string.format("CLAUDE_CODE_SSE_PORT=%d claude", port)

	-- Open in a new terminal split
	vim.cmd("split")
	vim.cmd("terminal " .. cmd)
	vim.cmd("resize 20")

	vim.notify(string.format("Claude Code launched with IDE port %d", port), vim.log.levels.INFO)
end

-- Launch Claude in external terminal (for macOS/Linux)
function M.open_claude_external()
	local port = websocket.get_info().port
	if not port then
		vim.notify("Claude IDE: WebSocket server not running", vim.log.levels.ERROR)
		return
	end

	local cmd
	if vim.fn.has("mac") == 1 then
		-- macOS: Use Terminal.app or iTerm2
		cmd = string.format(
			"osascript -e 'tell app \"Terminal\" to do script \"export CLAUDE_CODE_SSE_PORT=%d && claude\"'",
			port
		)
	else
		-- Linux: Try common terminal emulators
		cmd = string.format(
			"gnome-terminal -- bash -c 'export CLAUDE_CODE_SSE_PORT=%d && claude; exec bash' 2>/dev/null || "
				.. "konsole -e bash -c 'export CLAUDE_CODE_SSE_PORT=%d && claude; exec bash' 2>/dev/null || "
				.. "xterm -e bash -c 'export CLAUDE_CODE_SSE_PORT=%d && claude; exec bash' &",
			port,
			port,
			port
		)
	end

	vim.fn.system(cmd)
	vim.notify(string.format("Claude Code launching in external terminal with IDE port %d", port), vim.log.levels.INFO)
end

-- Setup commands
function M.setup()
	vim.api.nvim_create_user_command("ClaudeOpen", M.open_claude, {
		desc = "Open Claude Code with IDE integration",
	})

	vim.api.nvim_create_user_command("ClaudeOpenExternal", M.open_claude_external, {
		desc = "Open Claude Code in external terminal with IDE integration",
	})
end

return M