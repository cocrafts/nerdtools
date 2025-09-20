--- Test script for openFile tool
--- Run with :lua require("core.claude.tools.test_openfile").test()

local M = {}

function M.test()
	local websocket = require("core.claude.websocket")

	-- Ensure server is running
	if not websocket.is_connected() then
		vim.notify("Starting Claude IDE server...", vim.log.levels.INFO)
		websocket.start()
		vim.wait(2000) -- Wait for server to start
	end

	-- Simulate an openFile command being queued
	vim.notify("Testing openFile command...", vim.log.levels.INFO)

	-- The server would normally receive this from Claude via MCP
	-- For testing, we'll manually trigger a poll to demonstrate the mechanism
	websocket.poll_commands()

	vim.notify("Poll command sent. If there were queued commands, they would be processed.", vim.log.levels.INFO)

	-- To fully test, we would need Claude to actually send an openFile command
	-- through the MCP protocol. This test just verifies the infrastructure is working.
end

-- Create a command for easy testing
vim.api.nvim_create_user_command("ClaudeTestOpenFile", function()
	M.test()
end, { desc = "Test Claude openFile functionality" })

return M