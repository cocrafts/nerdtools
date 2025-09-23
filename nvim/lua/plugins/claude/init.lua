---@brief [[
--- Claude Code IDE Integration for Neovim
--- Pure Lua implementation following MCP (Model Context Protocol)
--- Based on claudecode.nvim architecture
---@brief ]]

---@module 'plugins.claude'
local M = {}

-- Module components
local buffer = require("plugins.claude.buffer")
local lockfile = require("plugins.claude.lockfile")
local logger = require("plugins.claude.logger")
local prompt = require("plugins.claude.prompt")
local selection = require("plugins.claude.selection")
local server = require("plugins.claude.server")

-- Module state
---@type table
M.state = {
	initialized = false,
	server = nil,
	port = nil,
	auth_token = nil,
}

--- Initialize the Claude IDE integration
---@param opts table|nil Optional configuration
---@return boolean success
---@return string|nil error_message
function M.setup(opts)
	opts = opts or {}

	if M.state.initialized then
		-- Already initialized
		return true
	end

	-- Initialize logger
	logger.setup(opts.log_level or vim.log.levels.INFO)

	-- Start WebSocket server with reconnection support
	local success, result, auth_token = server.start(opts)
	if not success then
		return false, result
	end

	M.state.server = server
	M.state.port = result
	M.state.auth_token = auth_token
	M.state.initialized = true

	-- Setup buffer tracking
	buffer.setup_tracking(server)

	-- Setup enhanced selection tracking
	selection.enable(server)

	-- Setup autocmds
	M._setup_autocmds()

	-- Started on port

	-- Set environment variables for Claude Code
	vim.env.CLAUDE_CODE_SSE_PORT = tostring(result)
	vim.env.ENABLE_IDE_INTEGRATION = "true"

	-- Setup user commands
	require("plugins.claude.commands").setup()

	-- Setup prompt module
	prompt.setup()

	-- Setup keybinding for <leader>ai
	vim.keymap.set({ "n", "v" }, "<leader>ai", function()
		prompt.open_prompt()
	end, { desc = "Open Claude prompt" })

	-- Note: Polling not needed - tools execute directly like claudecode.nvim

	return true
end

--- Stop the Claude IDE integration
function M.stop()
	if M.state.server then
		-- Stop selection tracking
		selection.disable()

		-- Stop buffer tracking
		buffer.stop_tracking()

		-- Stop server
		server.stop()

		-- Clean up lock file
		if M.state.port then
			lockfile.delete(M.state.port)
		end

		M.state.server = nil
		M.state.port = nil
		M.state.auth_token = nil
		M.state.initialized = false

		-- Clear environment variables
		vim.env.CLAUDE_CODE_SSE_PORT = nil
		vim.env.ENABLE_IDE_INTEGRATION = nil

		-- Stopped
	end
end

--- Check if Claude is connected
---@return boolean
function M.is_connected()
	if not M.state.server then
		return false
	end
	return server.is_connected()
end

--- Get server status
---@return table
function M.get_status()
	return {
		initialized = M.state.initialized,
		port = M.state.port,
		connected = M.is_connected(),
		client_count = M.state.server and server.get_client_count() or 0,
	}
end

--- Send @ mention to Claude
---@param file_path string
---@param text string
---@param start_line number|nil
---@param end_line number|nil
function M.send_mention(file_path, text, start_line, end_line)
	if not M.state.server then
		logger.warn("Server not initialized")
		return false
	end

	return server.send_at_mention({
		filePath = file_path,
		text = text,
		lineStart = start_line,
		lineEnd = end_line,
	})
end

--- Setup autocmds for Claude IDE
function M._setup_autocmds()
	local group = vim.api.nvim_create_augroup("ClaudeIDE", { clear = true })

	-- Clean up on exit
	vim.api.nvim_create_autocmd("VimLeave", {
		group = group,
		callback = function()
			M.stop()
		end,
		desc = "Stop Claude IDE on exit",
	})

	-- Selection tracking is handled by the selection module

	-- Send buffer content on save (for diagnostics)
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(args)
			if M.is_connected() then
				-- Could send buffer update notification here
				local filepath = vim.api.nvim_buf_get_name(args.buf)
				if filepath ~= "" then
					-- Future: send buffer content update
					-- Buffer saved
				end
			end
		end,
		desc = "Notify Claude of buffer saves",
	})
end

--- Create user commands
function M.create_commands()
	-- Start server
	vim.api.nvim_create_user_command("ClaudeStart", function()
		local success, err = M.setup()
		if success then
			vim.notify(string.format("Claude IDE started on port %d", M.state.port), vim.log.levels.INFO)
		else
			vim.notify("Failed to start Claude IDE: " .. (err or "unknown error"), vim.log.levels.ERROR)
		end
	end, { desc = "Start Claude IDE integration" })

	-- Stop server
	vim.api.nvim_create_user_command("ClaudeStop", function()
		M.stop()
		vim.notify("Claude IDE stopped", vim.log.levels.INFO)
	end, { desc = "Stop Claude IDE integration" })

	-- Show status
	vim.api.nvim_create_user_command("ClaudeStatus", function()
		local status = M.get_status()
		local lines = {
			"Claude IDE Status:",
			string.format("  Initialized: %s", status.initialized),
			string.format("  Port: %s", status.port or "N/A"),
			string.format("  Connected: %s", status.connected),
			string.format("  Clients: %d", status.client_count),
		}
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, { desc = "Show Claude IDE status" })

	-- Send selection
	vim.api.nvim_create_user_command("ClaudeSend", function(opts)
		local text = selection.get_visual_selection()
		if text and text ~= "" then
			local filepath = vim.api.nvim_buf_get_name(0)
			local start_line = vim.fn.line("'<")
			local end_line = vim.fn.line("'>")

			if M.send_mention(filepath, text, start_line, end_line) then
				vim.notify("Sent selection to Claude", vim.log.levels.INFO)
			else
				vim.notify("Failed to send to Claude", vim.log.levels.ERROR)
			end
		else
			vim.notify("No selection to send", vim.log.levels.WARN)
		end
	end, { desc = "Send selection to Claude", range = true })

	-- Restart server
	vim.api.nvim_create_user_command("ClaudeRestart", function()
		M.stop()
		vim.wait(100)
		local success, err = M.setup()
		if success then
			vim.notify(string.format("Claude IDE restarted on port %d", M.state.port), vim.log.levels.INFO)
		else
			vim.notify("Failed to restart Claude IDE: " .. (err or "unknown error"), vim.log.levels.ERROR)
		end
	end, { desc = "Restart Claude IDE integration" })
end

return M
