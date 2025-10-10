---@brief Popup prompt interface for Claude
---@module 'plugins.claude.prompt'

local M = {}

-- State for active prompts
local state = {
	buf = nil,
	win = nil,
	on_submit = nil,
	mode = nil, -- "execute" or "insert"
}

--- Create floating window at cursor position
---@return number buf Buffer number
---@return number win Window number
local function create_float_at_cursor()
	-- Get cursor position
	local cursor = vim.api.nvim_win_get_cursor(0)
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

--- Send prompt to Claude
---@param text string The prompt text
---@param mode string "execute", "insert", or "newline" - how to handle the prompt
---@param context table|nil Optional context with file info and selection
local function send_to_claude(text, mode, context)
	if text == "" then
		vim.notify("Empty prompt", vim.log.levels.WARN)
		return
	end

	mode = mode or "execute"

	-- Add file context for insert and newline modes
	if context and (mode == "insert" or mode == "newline") then
		local prefix = ""
		if context.filepath and context.filepath ~= "" then
			-- Create @file reference
			prefix = "@" .. context.filepath

			-- Add line numbers
			if context.start_line then
				if context.end_line and context.end_line ~= context.start_line then
					-- Multi-line selection
					prefix = prefix .. "#" .. context.start_line .. ":" .. context.end_line
				else
					-- Single line or cursor position
					prefix = prefix .. "#" .. context.start_line
				end
			end

			-- Add selected text if it's a fragment
			if context.selected_text and context.is_fragment then
				prefix = prefix .. " `" .. context.selected_text .. "`"
			end

			-- Combine with user prompt
			text = prefix .. " " .. text
		end
	end

	-- Find WezTerm pane with Claude Code (marked with ✳)
	local wezterm_cli = "wezterm cli"

	-- Get list of panes using correct command
	local panes_cmd = wezterm_cli .. " list --format json 2>/dev/null"
	local panes_json = vim.fn.system(panes_cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("WezTerm CLI not available or failed", vim.log.levels.ERROR)
		return
	end

	local ok, panes = pcall(vim.json.decode, panes_json)
	if not ok or not panes then
		vim.notify("Failed to parse WezTerm panes", vim.log.levels.ERROR)
		return
	end

	-- Find pane with "✳" in the title (Claude Code marker)
	local claude_pane_id = nil
	for _, pane in ipairs(panes) do
		if pane.title and (pane.title:match("✳") or pane.title == "claude") then
			claude_pane_id = pane.pane_id
			break
		end
	end

	if not claude_pane_id then
		vim.notify("Claude Code pane not found (looking for ✳ in title)", vim.log.levels.ERROR)
		return
	end

	-- Store current pane for returning later
	local current_pane = vim.env.WEZTERM_PANE

	-- Activate the Claude pane first
	vim.fn.system(string.format("%s activate-pane --pane-id %d", wezterm_cli, claude_pane_id))

	-- Escape special characters for shell and handle multiline
	-- Replace newlines with literal \n for send-text
	local escaped_text = text:gsub("'", "'\\''"):gsub("\n", "\\n")

	-- Send the text to the Claude pane
	-- Using send-text which sends keystrokes
	local send_cmd = string.format("%s send-text --pane-id %d '%s'", wezterm_cli, claude_pane_id, escaped_text)

	vim.fn.system(send_cmd)

	if mode == "execute" then
		-- Send Enter key to execute the prompt
		-- Send a literal carriage return character (ASCII 13)
		local enter_cmd = string.format("%s send-text --pane-id %d --no-paste \13", wezterm_cli, claude_pane_id)
		vim.fn.system(enter_cmd)

		vim.notify("Prompt sent and executed!", vim.log.levels.INFO)

		-- Switch back to current pane (stay in Neovim)
		if current_pane then
			vim.defer_fn(function()
				vim.fn.system(string.format("%s activate-pane --pane-id %s", wezterm_cli, current_pane))
			end, 100)
		end
	elseif mode == "newline" then
		-- Send with newline (for continuing with more fragments)
		-- Send a literal newline character
		local newline_cmd = string.format("%s send-text --pane-id %d '\n'", wezterm_cli, claude_pane_id)
		vim.fn.system(newline_cmd)

		vim.notify("Prompt sent with newline (continue adding)", vim.log.levels.INFO)

		-- Switch back to current pane (stay in Neovim)
		if current_pane then
			vim.defer_fn(function()
				vim.fn.system(string.format("%s activate-pane --pane-id %s", wezterm_cli, current_pane))
			end, 100)
		end
	else
		-- Insert mode: add space and stay in Claude pane
		local space_cmd = string.format("%s send-text --pane-id %d ' '", wezterm_cli, claude_pane_id)
		vim.fn.system(space_cmd)

		vim.notify("Prompt inserted, focus on Claude Code", vim.log.levels.INFO)
		-- Don't switch back - stay in Claude pane
	end
end

--- Close the prompt window
local function close_prompt()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.buf = nil
	state.win = nil
	state.on_submit = nil
	state.mode = nil
end

--- Setup keymaps for the prompt buffer
---@param buf number Buffer number
---@param context table|nil Context with file info and selection
local function setup_prompt_keymaps(buf, context)
	local opts = { buffer = buf, noremap = true, silent = true }

	-- Helper function to get prompt text
	local function get_prompt_text()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		return table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
	end

	-- Regular Enter to execute (send with Enter, stay in Neovim)
	vim.keymap.set("i", "<CR>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "execute", nil) -- No context for execute mode
		end

		close_prompt()
	end, opts)

	-- Also support Return as alternative
	vim.keymap.set("i", "<Return>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "execute", nil) -- No context for execute mode
		end

		close_prompt()
	end, opts)

	-- Shift+Enter to send with newline (for multiple fragments, stay in Neovim)
	vim.keymap.set("i", "<S-CR>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "newline", context) -- Include context
		end

		close_prompt()
	end, opts)

	-- Also support Shift+Return as alternative
	vim.keymap.set("i", "<S-Return>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "newline", context) -- Include context
		end

		close_prompt()
	end, opts)

	-- Ctrl+Enter to insert and switch focus (send with space, focus Claude)
	vim.keymap.set("i", "<C-CR>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "insert", context) -- Include context
		end

		close_prompt()
	end, opts)

	-- Also support Ctrl+Return as alternative
	vim.keymap.set("i", "<C-Return>", function()
		local text = get_prompt_text()

		if state.on_submit then
			state.on_submit(text)
		else
			send_to_claude(text, "insert", context) -- Include context
		end

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
			state.on_submit = nil
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

	-- Gather context information
	local filepath = vim.fn.expand("%:p")
	if filepath ~= "" then
		-- Make path relative to current working directory
		local cwd = vim.fn.getcwd()
		if filepath:sub(1, #cwd) == cwd then
			filepath = filepath:sub(#cwd + 2) -- Remove cwd and the trailing /
		end
	end

	local context = {
		filepath = filepath ~= "" and filepath or nil,
		start_line = vim.fn.line("."), -- Current line
		end_line = nil,
		selected_text = nil,
		is_fragment = false,
	}

	-- Check for visual selection and pre-fill prompt
	local initial_text = opts.initial_text
	local mode = vim.fn.mode()

	if mode:match("[vV\22]") then
		-- Get selection boundaries
		context.start_line = vim.fn.line("'<")
		context.end_line = vim.fn.line("'>")

		-- Check if it's visual line mode (full lines selected)
		if mode == "V" then
			-- Full lines selected - keep prompt empty
			-- The selected text will still be sent as context to Claude via MCP
			initial_text = nil
			context.is_fragment = false
		else
			-- Visual mode (character/block) - fragment selection
			vim.cmd('normal! "zy')
			local selected = vim.fn.getreg("z")

			if selected and selected ~= "" then
				-- Clean up the selection (trim whitespace)
				selected = selected:gsub("^%s+", ""):gsub("%s+$", "")
				context.selected_text = selected
				context.is_fragment = true
				-- Don't include in initial text anymore since we'll add it via context
				initial_text = ""
			end
		end
	end

	-- Create floating window
	local buf, win = create_float_at_cursor()
	state.buf = buf
	state.win = win
	state.on_submit = opts.on_submit
	state.mode = opts.mode or "execute"

	-- Setup keymaps with context
	setup_prompt_keymaps(buf, context)

	-- Set initial text if we have any
	if initial_text then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial_text, "\n"))
		-- Move cursor to end of text for easy continuation
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local last_line = #lines
		local last_col = #lines[last_line]
		vim.api.nvim_win_set_cursor(win, { last_line, last_col })
	end

	-- Enter insert mode
	vim.cmd("startinsert!")

	-- Show help in command line
	vim.api.nvim_echo({
		{ "Claude: ",             "Title" },
		{ "Enter",                "Special" },
		{ " = execute | ",        "Normal" },
		{ "Shift+Enter",          "Special" },
		{ " = newline | ",        "Normal" },
		{ "Ctrl+Enter",           "Special" },
		{ " = insert & focus | ", "Normal" },
		{ "Esc",                  "Special" },
		{ " = cancel",            "Normal" },
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
