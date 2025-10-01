---@brief Popup prompt interface for Claude
---@module 'plugins.claude.prompt'

local M = {}

-- State for active prompts
local state = {
	buf = nil,
	win = nil,
	selected_text = nil,
}

--- Create floating window at cursor position
---@return number buf Buffer number
---@return number win Window number
local function create_float_at_cursor()
	-- Get cursor position
	local win_row = vim.fn.winline()
	local win_col = vim.fn.wincol()

	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	-- Initial window config - 1 line height, 60 chars wide
	local width = 60
	local height = 1

	-- Calculate position relative to editor
	local opts = {
		relative = "editor",
		row = win_row - 1, -- Convert to 0-indexed
		col = win_col - 1,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Claude Prompt ",
		title_pos = "left",
	}

	-- Create window
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Set window options
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.api.nvim_win_set_option(win, "linebreak", true)
	vim.api.nvim_win_set_option(win, "cursorline", false)

	return buf, win
end

--- Auto-resize window based on content
---@param buf number Buffer number
---@param win number Window number
local function auto_resize_window(buf, win)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local line_count = #lines

	-- Calculate actual height needed (account for wrapped lines)
	local width = vim.api.nvim_win_get_width(win)
	local total_height = 0

	for _, line in ipairs(lines) do
		local line_width = vim.fn.strdisplaywidth(line)
		if line_width == 0 then
			total_height = total_height + 1
		else
			total_height = total_height + math.ceil(line_width / width)
		end
	end

	-- Limit height to reasonable maximum
	local new_height = math.min(math.max(1, total_height), 20)

	-- Get current config and update height
	local config = vim.api.nvim_win_get_config(win)
	if config.height ~= new_height then
		config.height = new_height
		vim.api.nvim_win_set_config(win, config)
	end
end

--- Send prompt to Claude and execute
---@param text string The prompt text
---@param selected_text string|nil Selected text to include
local function send_to_claude(text, selected_text)
	if text == "" and not selected_text then
		vim.notify("Empty prompt", vim.log.levels.WARN)
		return
	end

	-- Prepend selected text with backticks if present
	if selected_text and selected_text ~= "" then
		text = "`" .. selected_text .. "` " .. text
	end

	-- Find Tmux pane with Claude Code (marked with ✳)
	local panes_cmd = "tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_title}' 2>/dev/null"
	local panes_output = vim.fn.system(panes_cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Tmux not available or failed", vim.log.levels.ERROR)
		return
	end

	-- Find pane with "✳" or "claude" in the title (Claude Code marker)
	local claude_pane_target = nil
	for line in panes_output:gmatch("[^\r\n]+") do
		local target, title = line:match("([^|]+)|(.+)")
		if title and (title:match("✳") or title:match("claude")) then
			claude_pane_target = target
			break
		end
	end

	if not claude_pane_target then
		vim.notify("Claude Code pane not found (looking for ✳ or claude in title)", vim.log.levels.ERROR)
		return
	end

	-- Store current pane for returning later
	local current_pane = vim.fn.system("tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'"):gsub("\n", "")

	-- Activate the Claude pane first
	vim.fn.system(string.format("tmux select-pane -t '%s'", claude_pane_target))

	-- Escape single quotes for shell
	local escaped_text = text:gsub("'", "'\\''")

	-- Send the text to the Claude pane using send-keys with -l flag (literal)
	local send_cmd = string.format("tmux send-keys -t '%s' -l '%s'", claude_pane_target, escaped_text)
	vim.fn.system(send_cmd)

	-- Send Enter key to execute the prompt
	local enter_cmd = string.format("tmux send-keys -t '%s' Enter", claude_pane_target)
	vim.fn.system(enter_cmd)

	vim.notify("Prompt sent!", vim.log.levels.INFO)

	-- Switch back to Neovim
	if current_pane and current_pane ~= "" then
		vim.defer_fn(function()
			vim.fn.system(string.format("tmux select-pane -t '%s'", current_pane))
		end, 100)
	end
end

--- Close the prompt window
local function close_prompt()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.buf = nil
	state.win = nil
	state.selected_text = nil
end

--- Setup keymaps for the prompt buffer
---@param buf number Buffer number
local function setup_prompt_keymaps(buf)
	local opts = { buffer = buf, noremap = true, silent = true }

	-- Helper function to get prompt text
	local function get_prompt_text()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		return table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
	end

	-- Shift+Enter to send and execute
	vim.keymap.set("i", "<S-CR>", function()
		local text = get_prompt_text()
		send_to_claude(text, state.selected_text)
		close_prompt()
	end, opts)

	-- Escape to cancel
	vim.keymap.set("i", "<Esc>", function()
		close_prompt()
	end, opts)

	-- Auto-resize on text change
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = buf,
		callback = function()
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				auto_resize_window(buf, state.win)
			end
		end,
	})

	-- Clean up state when buffer is deleted
	vim.api.nvim_create_autocmd("BufDelete", {
		buffer = buf,
		once = true,
		callback = function()
			state.buf = nil
			state.win = nil
			state.selected_text = nil
		end,
	})
end

--- Open prompt popup at cursor
---@param opts table|nil Options
---@return boolean success
function M.open_prompt(opts)
	opts = opts or {}

	-- Close existing prompt if any
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		close_prompt()
	end

	-- Capture selected text only if it's a fragment (character-wise visual mode)
	local mode = vim.fn.mode()
	if mode == "v" then
		-- Character-wise visual mode - capture fragment
		vim.cmd('normal! "zy')
		local selected = vim.fn.getreg("z")
		-- Only include if it's a single line fragment
		if selected and not selected:match("\n") then
			state.selected_text = selected
		else
			state.selected_text = nil
		end
	else
		-- Line-wise (V) or block-wise (^V) - don't include selected text
		state.selected_text = nil
	end

	-- Create floating window
	local buf, win = create_float_at_cursor()
	state.buf = buf
	state.win = win

	-- Setup keymaps
	setup_prompt_keymaps(buf)

	-- Set initial text if provided
	if opts.initial_text then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.initial_text, "\n"))
		-- Move cursor to end of text
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local last_line = #lines
		local last_col = #lines[last_line]
		vim.api.nvim_win_set_cursor(win, { last_line, last_col })
	end

	-- Enter insert mode
	vim.cmd("startinsert!")

	-- Show help in command line
	vim.api.nvim_echo({
		{ "Claude: ", "Title" },
		{ "Enter", "Special" },
		{ " = newline | ", "Normal" },
		{ "Shift+Enter", "Special" },
		{ " = send | ", "Normal" },
		{ "Esc", "Special" },
		{ " = cancel", "Normal" },
	}, false, {})

	return true
end

--- Setup the prompt module
function M.setup()
	-- Create command
	vim.api.nvim_create_user_command("ClaudePrompt", function(args)
		M.open_prompt({
			initial_text = args.args,
		})
	end, {
		desc = "Open Claude prompt popup",
		nargs = "?",
	})
end

return M
