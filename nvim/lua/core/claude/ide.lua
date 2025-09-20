--- IDE registration for Claude Code with optional WebSocket
--- @module 'core.claude.ide'

local M = {}
local websocket = require("core.claude.websocket")

-- Create IDE lock file (handled by Nim server now)
function M.register()
	-- Start WebSocket server (Nim server handles lock file)
	local port, auth_token = websocket.start()
	if not port then
		return false, "Failed to initialize"
	end
	return true, nil
end

-- Remove IDE lock file and stop server (handled by Nim server now)
function M.unregister()
	websocket.stop()
end

-- Send to Claude via WebSocket or WezTerm
function M.send_to_claude(filepath, text, line_start, line_end)
	return websocket.send_mention(filepath, text, line_start, line_end)
end

-- Check connection status
function M.is_connected()
	return websocket.is_connected()
end

-- Get IDE info
function M.get_info()
	return websocket.get_info()
end

-- Restart the IDE server (unregister and register again)
function M.restart()
	vim.notify("Claude IDE: Restarting...", vim.log.levels.INFO)

	-- Stop existing server
	M.unregister()

	-- Wait a bit for cleanup
	vim.wait(100)

	-- Start fresh
	local success, err = M.register()
	if success then
		local port = websocket.get_info().port
		vim.notify(string.format("Claude IDE: Restarted on port %d", port), vim.log.levels.INFO)

		-- Re-setup autocmds
		require("core.claude.autocmds").setup()
		return true
	else
		vim.notify("Claude IDE: Restart failed - " .. (err or "unknown error"), vim.log.levels.ERROR)
		return false
	end
end

-- Setup function
function M.setup()
	-- Always unregister first to ensure clean state
	M.unregister()
	vim.wait(100) -- Small delay for cleanup

	-- Register on startup
	local success, err = M.register()
	if success then
		vim.notify("Claude IDE: WebSocket server started", vim.log.levels.INFO)
	else
		vim.notify("Claude IDE: Failed to start - " .. (err or "unknown error"), vim.log.levels.ERROR)
		return
	end

	-- Setup autocmds for buffer/selection notifications (minimal for performance)
	require("core.claude.autocmds").setup()

	-- Setup session management for multiple Neovim/Claude pairs
	require("core.claude.sessions").setup()

	-- Create user commands
	vim.api.nvim_create_user_command("ClaudeRestart", M.restart, {
		desc = "Restart Claude IDE server",
	})

	vim.api.nvim_create_user_command("ClaudeStop", M.unregister, {
		desc = "Stop Claude IDE server",
	})

	vim.api.nvim_create_user_command("ClaudeStart", function()
		M.register()
		vim.notify("Claude IDE: Started on port " .. tostring(websocket.get_info().port), vim.log.levels.INFO)
	end, {
		desc = "Start Claude IDE server",
	})

	local port = websocket.get_info().port
	vim.notify(
		string.format("Claude IDE: Ready on port %d\nCommands: :ClaudeRestart, :ClaudeSessions", port),
		vim.log.levels.INFO
	)

	-- Cleanup on exit
	vim.api.nvim_create_autocmd("VimLeave", {
		callback = M.unregister,
	})

	-- Optional: Add keybinding for quick restart (users can customize)
	vim.keymap.set("n", "<leader>cr", M.restart, { desc = "Restart Claude IDE", silent = true })
end

return M