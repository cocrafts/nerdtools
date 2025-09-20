--- UI helpers for Claude integration
--- Provides floating windows, prompts, and status displays
--- @module 'core.claude.ui'

local M = {}
local config = require("core.claude.config")

-- Show status message (toast notification)
function M.show_status(message, timeout)
	timeout = timeout or config.get("status_timeout_ms") or 5000
	vim.notify(message, vim.log.levels.INFO)
end

-- Show floating prompt window with dynamic resize
function M.show_prompt_window(initial_text, callback)
	initial_text = initial_text or ""

	-- Create buffer for the prompt
	local buf = vim.api.nvim_create_buf(false, true)

	-- Get window dimensions
	local width = math.min(80, math.floor(vim.o.columns * 0.8))
	local initial_lines = vim.split(initial_text .. " ", "\n", { plain = true })
	local initial_height = math.max(1, #initial_lines)
	local max_height = math.min(20, math.floor(vim.o.lines * 0.4))

	-- Get prompt window config
	local prompt_config = config.get("prompt_window") or {}
	local border = prompt_config.border or "rounded"
	local title = prompt_config.title or " Claude Prompt (Shift+Enter to send, Esc to cancel) "
	local title_pos = prompt_config.title_pos or "center"

	-- Open floating window at cursor position
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		width = width,
		height = math.min(initial_height, max_height),
		row = 1,     -- 1 line below cursor
		col = 0,     -- aligned with cursor column
		anchor = "NW", -- northwest corner at the position
		border = border,
		title = title,
		title_pos = title_pos,
		style = "minimal",
	})

	-- Set initial content
	local lines = vim.split(initial_text, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Configure buffer
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	-- Function to resize window based on content
	local function resize_window()
		local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local line_count = #buf_lines

		-- Count wrapped lines
		for _, line in ipairs(buf_lines) do
			if #line > width then
				line_count = line_count + math.floor(#line / width)
			end
		end

		-- Update window height, respecting max height
		local new_height = math.min(line_count, max_height)
		vim.api.nvim_win_set_config(win, { height = new_height })
	end

	-- Auto-resize on text change
	vim.api.nvim_buf_attach(buf, false, {
		on_lines = function()
			vim.schedule(resize_window)
		end,
	})

	-- Position cursor at end of initial text and start insert mode
	local last_line = #lines
	local last_col = #lines[last_line]
	vim.api.nvim_win_set_cursor(win, { last_line, last_col })
	vim.schedule(function()
		vim.cmd("startinsert!")
	end)

	-- Key mappings
	local opts = { noremap = true, silent = true, buffer = buf }

	-- Function to submit the prompt
	local function submit()
		local buf_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local input = table.concat(buf_content, "\n")
		vim.api.nvim_win_close(win, true)
		if callback then
			callback(input)
		end
	end

	-- Function to cancel
	local function cancel()
		vim.api.nvim_win_close(win, true)
		if callback then
			callback(nil)
		end
	end

	-- Enter to send (in normal mode)
	vim.keymap.set("n", "<CR>", submit, opts)

	-- Shift+Enter to send (in insert mode)
	vim.keymap.set("i", "<S-CR>", submit, opts)

	-- Escape to cancel
	vim.keymap.set({ "n", "i" }, "<Esc>", cancel, opts)

	-- Optional: Enter in insert mode adds newline (normal behavior)
	vim.keymap.set("i", "<CR>", function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
	end, opts)
end

-- Show simple input dialog (single line)
function M.show_input_dialog(prompt, default, callback)
	vim.ui.input({
		prompt = prompt,
		default = default,
	}, function(input)
		if callback then
			callback(input)
		end
	end)
end

-- Show selection dialog
function M.show_select_dialog(items, opts, callback)
	vim.ui.select(items, opts, function(choice, idx)
		if callback then
			callback(choice, idx)
		end
	end)
end

-- Show error message
function M.show_error(message)
	vim.notify(message, vim.log.levels.ERROR)
end

-- Show warning message
function M.show_warning(message)
	vim.notify(message, vim.log.levels.WARN)
end

-- Show info message
function M.show_info(message)
	vim.notify(message, vim.log.levels.INFO)
end

-- Create a status line component for lualine
function M.get_lualine_component()
	if not config.get("show_status_in_lualine") then
		return nil
	end

	return {
		function()
			local session = require("core.claude.session")
			if session.is_claude_active() then
				return "󰆙 Claude"
			end
			return ""
		end,
		color = { fg = "#00ff00" },
	}
end

-- Setup function
function M.setup(opts)
	-- No specific setup needed for now
end

return M