--- Quick status check for Claude IDE integration
--- @module 'core.claude.status'

local M = {}

-- Quick status check that doesn't block
function M.check()
	local websocket = require("core.claude.websocket")
	local info = websocket.get_info()

	local status = {}
	table.insert(status, "=== Claude IDE Status ===")
	table.insert(status, string.format("Running: %s", tostring(info.running)))
	table.insert(status, string.format("Port: %s", tostring(info.port or "none")))
	table.insert(status, string.format("Connected: %s", tostring(info.connected)))
	table.insert(status, string.format("Binary: %s", info.binary_path or "not found"))

	if info.port then
		table.insert(status, string.format("Auth: %s...", string.sub(info.auth_token or "", 1, 8)))
		table.insert(status, string.format("Env: CLAUDE_CODE_SSE_PORT=%s", vim.env.CLAUDE_CODE_SSE_PORT or "not set"))

		-- Check lock file
		local lock_file = vim.fn.expand("~/.claude/ide/" .. info.port .. ".lock")
		if vim.fn.filereadable(lock_file) == 1 then
			table.insert(status, string.format("Lock: %s ✓", lock_file))
		else
			table.insert(status, string.format("Lock: %s ✗", lock_file))
		end
	end

	-- Show in floating window
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, status)

	local width = 0
	for _, line in ipairs(status) do
		width = math.max(width, #line)
	end

	local opts = {
		relative = "editor",
		width = width + 4,
		height = #status,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - #status) / 2),
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Close on any key press
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { silent = true })

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

	return status
end

-- Vim command
vim.api.nvim_create_user_command("ClaudeStatus", function()
	M.check()
end, {
	desc = "Show Claude IDE connection status",
})

return M