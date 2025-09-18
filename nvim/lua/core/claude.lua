local M = {}

-- Configuration
local config = {
	tracking_file = vim.fn.expand("~/.claude/active-sessions.txt"),
}

-- Read active Claude sessions from tracking file
local function read_claude_sessions()
	local sessions = {}
	local file = io.open(config.tracking_file, "r")
	if not file then
		return sessions
	end

	for line in file:lines() do
		local session_id, dir, timestamp = line:match("^([^:]+):([^:]+):(.+)$")
		if session_id and dir then
			table.insert(sessions, {
				id = session_id,
				dir = dir,
				timestamp = timestamp,
			})
		end
	end
	file:close()
	return sessions
end

-- Get project root (git root or current directory)
local function get_project_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
	if vim.v.shell_error == 0 and git_root ~= "" then
		return git_root
	end
	return vim.fn.getcwd()
end

-- Find Claude session matching current directory
local function find_matching_session()
	local current_dir = get_project_root()
	local sessions = read_claude_sessions()

	for _, session in ipairs(sessions) do
		if session.dir == current_dir then
			return session
		end
	end

	-- Check if current dir is a subdirectory of any session
	for _, session in ipairs(sessions) do
		if current_dir:sub(1, #session.dir) == session.dir then
			return session
		end
	end

	return nil
end

-- Helper to escape text for shell
local function escape_text(text)
	return text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("`", "\\`")
end

-- Helper to send text to a pane
local function send_to_pane(pane_id, text, send_enter)
	text = escape_text(text)
	local cmd = string.format('printf "%%s" "%s" | wezterm cli send-text --pane-id %d', text, pane_id)
	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		return false, result
	end

	if send_enter then
		vim.fn.system(string.format("printf '\\r' | wezterm cli send-text --no-paste --pane-id %d", pane_id))
	end

	return true
end

-- Find Claude pane in list
local function find_claude_pane(panes, current_pane)
	local claude_sessions = read_claude_sessions()
	local claude_dirs = {}
	for _, session in ipairs(claude_sessions) do
		claude_dirs[session.dir] = true
	end

	for _, pane in ipairs(panes) do
		if pane.pane_id ~= current_pane and pane.foreground_process_name == "claude" then
			-- Check if it also matches a session directory
			if pane.cwd then
				local pane_dir = pane.cwd:gsub("^file://[^/]+", "")
				if claude_dirs[pane_dir] then
					return pane.pane_id, pane.window_id -- Prefer session-matched Claude
				end
			end
			return pane.pane_id, pane.window_id -- Any Claude pane
		end
	end
	return nil
end

-- Get next pane in direction
local function get_next_pane(direction)
	local result = vim.fn.system("wezterm cli get-pane-direction " .. direction)
	if vim.v.shell_error == 0 and result then
		local cleaned = result:gsub("\n", ""):gsub("%s+", "")
		if cleaned ~= "" then
			return tonumber(cleaned)
		end
	end
	return nil
end

-- Helper function to show status in Lualine
local function show_status(msg, timeout)
	timeout = timeout or 5000 -- Default 2 seconds

	-- Check if Lualine is available
	local has_lualine = pcall(require, "lualine")
	if has_lualine then
		vim.g.claude_status = msg
		require("lualine").refresh()

		-- Clear after timeout
		vim.defer_fn(function()
			vim.g.claude_status = nil
			require("lualine").refresh()
		end, timeout)
	else
		-- Fallback to vim.notify
		vim.notify(msg, vim.log.levels.INFO)
	end
end

-- Send text to Claude (WezTerm or clipboard)
local function send_to_claude(text, send_enter, focus_pane)
	-- Check if we're in WezTerm
	if os.getenv("TERM_PROGRAM") ~= "WezTerm" or not os.getenv("WEZTERM_PANE") then
		vim.fn.setreg("+", text)
		show_status("Prompt copied to clipboard")
		return
	end

	local current_pane = tonumber(os.getenv("WEZTERM_PANE"))

	-- Try to find Claude pane
	local panes_json = vim.fn.system("wezterm cli list --format json")
	if vim.v.shell_error == 0 then
		local ok, panes = pcall(vim.json.decode, panes_json)
		if ok and panes and #panes > 0 then
			-- Find current window
			local current_window_id
			for _, pane in ipairs(panes) do
				if pane.pane_id == current_pane then
					current_window_id = pane.window_id
					break
				end
			end

			-- Try to find Claude pane
			local claude_pane_id, claude_window_id = find_claude_pane(panes, current_pane)
			if claude_pane_id then
				local success, err = send_to_pane(claude_pane_id, text, send_enter)
				if success then
					local window_desc = claude_window_id == current_window_id and "same window"
							or "window " .. claude_window_id
					show_status(string.format("→ Pane %d (%s)", claude_pane_id, window_desc))

					if focus_pane and claude_window_id == current_window_id then
						vim.fn.system(string.format("wezterm cli activate-pane --pane-id %d", claude_pane_id))
					end
				else
					show_status("Failed: " .. err, 3000) -- Show errors longer
				end
				return
			end
		end
	end

	-- No Claude found, try next pane (right or down)
	local next_pane_id = get_next_pane("right") or get_next_pane("down")
	if next_pane_id and next_pane_id ~= current_pane then
		local success = send_to_pane(next_pane_id, text, send_enter)
		if success then
			show_status(string.format("→ Pane %d", next_pane_id))
			if focus_pane then
				vim.fn.system(string.format("wezterm cli activate-pane --pane-id %d", next_pane_id))
			end
			return
		end
	end

	-- No panes available
	show_status("Claude Code panel does not exists", 3000)
end

-- Get diagnostics for a line or range
local function get_diagnostics_for_lines(start_line, end_line)
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)
	local relevant_diagnostics = {}

	for _, diag in ipairs(diagnostics) do
		-- vim.diagnostic uses 0-indexed lines
		local diag_line = diag.lnum + 1
		if diag_line >= start_line and diag_line <= end_line then
			table.insert(relevant_diagnostics, diag)
		end
	end

	if #relevant_diagnostics == 0 then
		return nil
	end

	-- Format diagnostics
	local formatted = {}
	for _, diag in ipairs(relevant_diagnostics) do
		local severity = vim.diagnostic.severity[diag.severity]
		local line = diag.lnum + 1
		local message = diag.message:gsub("\n", " ")
		local source = diag.source and (" [" .. diag.source .. "]") or ""
		table.insert(formatted, string.format("[%s] Line %d: %s%s", severity, line, message, source))
	end

	return table.concat(formatted, "\n")
end

-- Build file reference with optional line numbers
local function build_file_reference()
	local mode = vim.fn.mode()
	local filepath = vim.fn.expand("%:p")

	if filepath == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return nil
	end

	-- Get project root and make path relative
	local project_root = get_project_root()
	local relative_path = filepath
	if filepath:sub(1, #project_root) == project_root then
		relative_path = filepath:sub(#project_root + 2) -- +2 to skip the trailing slash
	end

	-- In normal mode, check for diagnostics on current line
	if mode == "n" then
		local current_line = vim.fn.line(".")
		local diagnostics = get_diagnostics_for_lines(current_line, current_line)
		local base_ref = "@" .. relative_path .. ":" .. current_line

		if diagnostics then
			return base_ref .. " has errors:\n" .. diagnostics .. "\n\n"
		else
			return "@" .. relative_path
		end
	end

	-- In visual mode, add line numbers and possibly selected text
	if mode == "v" or mode == "V" or mode == "\22" then -- \22 is Ctrl-V
		-- Get actual visual selection line numbers
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")

		-- Ensure start_line is less than end_line
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		-- Check if it's a partial line selection (single line, character-wise visual mode)
		if start_line == end_line and mode == "v" then
			-- Get visual selection columns
			local v_start = vim.fn.getpos("v")
			local v_end = vim.fn.getpos(".")
			local start_col = v_start[3]
			local end_col = v_end[3]

			-- Ensure start_col is before end_col
			if start_col > end_col then
				start_col, end_col = end_col, start_col
			end

			-- Get the full line
			local full_line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1] or ""

			-- Extract the selected portion
			local selected_text = full_line:sub(start_col, end_col)

			-- Exit visual mode AFTER getting the text
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

			-- Get diagnostics for the line
			local diagnostics = get_diagnostics_for_lines(start_line, start_line)

			-- Check if it's a partial selection (selected text exists and is not the full line)
			local result
			if selected_text and selected_text ~= "" and selected_text:match("%S") then
				-- Always include selected text if it exists and has non-whitespace
				result = string.format("@%s:%d `%s`", relative_path, start_line, selected_text)
			else
				-- Empty or whitespace-only selection
				result = string.format("@%s:%d", relative_path, start_line)
			end

			-- Add diagnostics if present
			if diagnostics then
				result = result .. " has errors:\n" .. diagnostics .. "\n\n"
			end

			-- vim.notify("Returning: " .. result, vim.log.levels.INFO)
			return result
		else
			-- Exit visual mode
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

			-- Get diagnostics for the range
			local diagnostics = get_diagnostics_for_lines(start_line, end_line)

			-- Multiple lines or line-wise visual mode
			local result
			if start_line == end_line then
				result = string.format("@%s:%d", relative_path, start_line)
			else
				result = string.format("@%s:%d-%d", relative_path, start_line, end_line)
			end

			-- Add diagnostics if present
			if diagnostics then
				result = result .. " has errors:\n" .. diagnostics .. "\n\n"
			end

			return result
		end
	end

	return nil
end

-- Smart send to Claude
function M.smart_send()
	local reference = build_file_reference()
	if reference then
		-- Add a space after the reference for easier typing in Claude
		send_to_claude(reference .. " ", false, true) -- no enter, yes focus
	end
end

-- Smart send with prompt (multiline)
function M.smart_send_with_prompt()
	local reference = build_file_reference()
	if not reference then
		return
	end

	-- Create a floating window for multiline input
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.min(80, math.floor(vim.o.columns * 0.8))
	-- Calculate initial height based on reference content
	local initial_lines = vim.split(reference .. " ", "\n", { plain = true })
	local initial_height = math.max(1, #initial_lines) -- At least 1 line, or more if we have diagnostics
	local max_height = math.min(20, math.floor(vim.o.lines * 0.4))

	-- Use cursor-relative positioning
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		width = width,
		height = math.min(initial_height, max_height), -- Don't exceed max height initially
		row = 1,                                     -- 1 line below cursor
		col = 0,                                     -- aligned with cursor column
		anchor = "NW",                               -- northwest corner at the position
		border = "rounded",
		title = " Claude Prompt (Shift+Enter to send, Esc to cancel) ",
		title_pos = "center",
		style = "minimal",
	})

	-- Set initial content with reference and space
	local initial_text = reference .. " "
	-- Split the text by newlines to handle multi-line content (e.g., with diagnostics)
	local lines = vim.split(initial_text, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Set buffer options
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	-- Function to resize window based on content
	local function resize_window()
		local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local line_count = #buf_lines

		-- Count wrapped lines if wrap is enabled
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

	-- Position cursor at end of first line and start insert mode
	vim.api.nvim_win_set_cursor(win, { 1, #initial_text })
	vim.schedule(function()
		vim.cmd("startinsert!")
	end)

	-- Key mappings for the floating window
	local opts = { noremap = true, silent = true, buffer = buf }

	-- Enter to send (in normal mode)
	vim.keymap.set("n", "<CR>", function()
		local buf_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local input = table.concat(buf_content, "\n")
		vim.api.nvim_win_close(win, true)
		if input and input ~= "" then
			-- Send input with Enter key to execute, but don't focus
			send_to_claude(input, true, false) -- yes enter, no focus
		end
	end, opts)

	-- Shift+Enter to send (in insert mode)
	vim.keymap.set("i", "<S-CR>", function()
		local buf_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local input = table.concat(buf_content, "\n")
		vim.api.nvim_win_close(win, true)
		if input and input ~= "" then
			send_to_claude(input, true, false)
		end
	end, opts)

	-- Escape to cancel
	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, opts)
end

-- List active Claude sessions
function M.list_sessions()
	local sessions = read_claude_sessions()
	if #sessions == 0 then
		vim.notify("No active Claude sessions found", vim.log.levels.INFO)
		return
	end

	local current_session = find_matching_session()
	print("Active Claude sessions:")
	for i, session in ipairs(sessions) do
		local marker = current_session and session.id == current_session.id and " <- current" or ""
		print(string.format("%d. %s%s", i, session.dir, marker))
	end
end

-- Test sending to specific pane
function M.test_send(pane_id)
	if not pane_id then
		vim.notify("Usage: :ClaudeTest <pane_id>", vim.log.levels.ERROR)
		return
	end

	pane_id = tonumber(pane_id)
	if not pane_id then
		vim.notify("Invalid pane ID. Must be a number.", vim.log.levels.ERROR)
		return
	end

	local current_pane = tonumber(os.getenv("WEZTERM_PANE"))
	if pane_id == current_pane then
		vim.notify("Cannot send to current pane (Neovim is running here)", vim.log.levels.WARN)
		return
	end

	print(string.format("Sending test messages to pane %d...", pane_id))

	-- Method 1: Using printf (most reliable)
	local cmd1 = string.format('printf "Test 1: Using printf" | wezterm cli send-text --pane-id %d', pane_id)
	vim.fn.system(cmd1)
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	-- Method 2: Direct text with proper escaping
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d "Test 2: Direct text"', pane_id))
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	-- Method 3: Test multiline
	local multiline = "Test 3: Line 1\\nTest 3: Line 2"
	local cmd3 = string.format('printf "%s" | wezterm cli send-text --pane-id %d', multiline, pane_id)
	vim.fn.system(cmd3)
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	print("Test messages sent. Check pane " .. pane_id)
end

-- List WezTerm panes (more detailed debug)
function M.list_panes()
	local panes_json = vim.fn.system("wezterm cli list --format json")
	if vim.v.shell_error == 0 then
		local ok, panes = pcall(vim.json.decode, panes_json)
		if ok and panes then
			local current_pane = tonumber(os.getenv("WEZTERM_PANE"))
			local project_root = get_project_root()
			print("WezTerm panes (detailed):")
			print(string.format("  Current WEZTERM_PANE: %s (where Neovim is running)", current_pane or "not set"))
			print(string.format("  Current project root: %s", project_root))
			print("")

			-- Group panes by window
			local windows = {}
			for _, pane in ipairs(panes) do
				windows[pane.window_id] = windows[pane.window_id] or {}
				table.insert(windows[pane.window_id], pane)
			end

			-- Display panes grouped by window
			for window_id, window_panes in pairs(windows) do
				print(string.format("Window %d:", window_id))
				for _, pane in ipairs(window_panes) do
					local is_claude = false
					local is_current = (pane.pane_id == current_pane)
					local is_same_dir = false
					local markers = {}

					-- Read active Claude sessions
					local claude_sessions = read_claude_sessions()
					local claude_dirs = {}
					for _, session in ipairs(claude_sessions) do
						claude_dirs[session.dir] = true
					end

					-- Check if Claude is actively running
					if pane.foreground_process_name == "claude" then
						is_claude = true
						-- Check if it also matches a session directory
						if pane.cwd then
							local pane_dir = pane.cwd:gsub("^file://[^/]+", "")
							if claude_dirs[pane_dir] then
								table.insert(markers, "active session")
							else
								table.insert(markers, "active")
							end
						else
							table.insert(markers, "active")
						end
					elseif pane.cwd then
						-- Check if directory matches but Claude not running (stale)
						local pane_dir = pane.cwd:gsub("^file://[^/]+", "")
						if claude_dirs[pane_dir] then
							table.insert(markers, "stale session")
						end
					end

					-- Check if same directory
					if pane.cwd then
						local pane_dir = pane.cwd:gsub("^file://[^/]+", "")
						if pane_dir == project_root then
							is_same_dir = true
						end
					end

					local marker = ""
					if is_current then
						marker = " <- CURRENT (Neovim)"
					elseif is_claude then
						marker = " <- CLAUDE (" .. table.concat(markers, "+") .. ")"
					elseif is_same_dir then
						marker = " <- SAME DIR"
					end

					print(string.format("  Pane %d:%s", pane.pane_id, marker))
					print(string.format("    Title: %s", pane.title or "none"))
					print(string.format("    Process: %s", pane.foreground_process_name or "none"))
					if pane.cwd then
						local clean_cwd = pane.cwd:gsub("^file://[^/]+", "")
						print(string.format("    CWD: %s", clean_cwd))
					else
						print("    CWD: none")
					end
					print("")
				end
			end
		else
			vim.notify("Failed to parse panes JSON", vim.log.levels.ERROR)
		end
	else
		vim.notify("Failed to list WezTerm panes. Are you in WezTerm?", vim.log.levels.ERROR)
	end
end

-- Setup function
function M.setup(opts)
	config = vim.tbl_extend("force", config, opts or {})

	-- Create keymaps
	vim.keymap.set({ "n", "v" }, "<leader>aI", M.smart_send, { desc = "Send to Claude" })
	vim.keymap.set({ "n", "v" }, "<leader>ai", M.smart_send_with_prompt, { desc = "Send to Claude with prompt" })

	-- Create commands
	vim.api.nvim_create_user_command("ClaudePanes", M.list_panes, {})
	vim.api.nvim_create_user_command("ClaudeSessions", M.list_sessions, {})
	vim.api.nvim_create_user_command("ClaudeTest", function(cmd_opts)
		M.test_send(cmd_opts.args)
	end, { nargs = 1, desc = "Test sending to specific WezTerm pane" })
end

return M
