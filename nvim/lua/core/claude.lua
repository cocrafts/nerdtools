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

-- Send text to Claude (WezTerm or clipboard)
local function send_to_claude(text, send_enter, focus_pane)
	-- Check if we're in WezTerm
	local term_program = os.getenv("TERM_PROGRAM")
	local wezterm_pane = os.getenv("WEZTERM_PANE")

	if term_program == "WezTerm" and wezterm_pane then
		local current_pane = tonumber(wezterm_pane)
		local project_root = get_project_root()

		-- Use WezTerm CLI to send to other panes (including other windows)
		local panes_json = vim.fn.system("wezterm cli list --format json")
		if vim.v.shell_error == 0 then
			-- Parse JSON to find Claude pane
			local ok, panes = pcall(vim.json.decode, panes_json)
			if ok and panes then
				-- Read active Claude sessions to match by directory
				local claude_sessions = read_claude_sessions()
				local claude_dirs = {}
				for _, session in ipairs(claude_sessions) do
					claude_dirs[session.dir] = true
				end

				local claude_pane_id = nil
				local same_dir_pane_id = nil
				local current_window_id = nil

				-- First pass: find current window and Claude panes
				for _, pane in ipairs(panes) do
					-- Get current window ID
					if pane.pane_id == current_pane then
						current_window_id = pane.window_id
					end

					-- Skip current pane for Claude detection
					if pane.pane_id ~= current_pane then
						local pane_dir = nil
						if pane.cwd then
							pane_dir = pane.cwd:gsub("^file://[^/]+", "") -- Remove file://hostname prefix
						end

						-- Method 1: Check if pane's directory matches a Claude session AND claude is running
						if pane_dir and claude_dirs[pane_dir] and pane.foreground_process_name == "claude" then
							claude_pane_id = pane.pane_id
							break -- Found active Claude by session tracking
						end

						-- Method 2: Check if process name is 'claude' (fallback)
						if not claude_pane_id and pane.foreground_process_name == "claude" then
							claude_pane_id = pane.pane_id
							-- Don't break, keep looking for session-matched pane
						end

						-- Don't use same-dir fallback if just a shell is running
						-- (Avoid sending to panes where Claude was closed)
						if
								pane_dir == project_root
								and pane.foreground_process_name ~= "zsh"
								and pane.foreground_process_name ~= "bash"
								and pane.foreground_process_name ~= "fish"
								and pane.foreground_process_name ~= "sh"
						then
							same_dir_pane_id = pane.pane_id
						end
					end
				end

				-- Use Claude pane if found, otherwise same-dir pane
				local target_pane_id = claude_pane_id or same_dir_pane_id

				if target_pane_id then
					-- Send text to target pane (escape special characters including backticks)
					text = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("`", "\\`")
					local cmd =
							string.format('printf "%%s" "%s" | wezterm cli send-text --pane-id %d', text, target_pane_id)
					vim.fn.system(cmd)
					-- Send Enter key if requested
					if send_enter then
						-- Send Enter key to submit (send raw Enter/Return character)
						vim.fn.system(
							string.format(
								"printf '\\r' | wezterm cli send-text --no-paste --pane-id %d",
								target_pane_id
							)
						)
					end

					-- Find which window the target pane is in for better notification
					local target_window = "unknown"
					for _, pane in ipairs(panes) do
						if pane.pane_id == target_pane_id then
							if pane.window_id == current_window_id then
								target_window = "same window"
							else
								target_window = "window " .. pane.window_id
							end
							break
						end
					end

					local pane_type = claude_pane_id and "Claude" or "same-dir"
					vim.notify(
						string.format("Sent to %s pane %d (%s)", pane_type, target_pane_id, target_window),
						vim.log.levels.INFO
					)

					-- Focus the target pane if requested (only works within same window)
					if focus_pane and target_window == "same window" then
						local focus_cmd = string.format("wezterm cli activate-pane --pane-id %d", target_pane_id)
						vim.fn.system(focus_cmd)
					end

					return
				end
			end
		end

		-- If no Claude pane found, try to use the right pane
		local next_pane = vim.fn.system("wezterm cli get-pane-direction right")
		if vim.v.shell_error == 0 and next_pane ~= "" then
			local pane_id = tonumber(next_pane:gsub("\n", ""))
			if pane_id and pane_id ~= current_pane then
				text = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("`", "\\`")
				local cmd = string.format('printf "%%s" "%s" | wezterm cli send-text --pane-id %d', text, pane_id)
				vim.fn.system(cmd)
				-- Send Enter key if requested
				if send_enter then
					-- Send Enter key to submit (send raw Enter/Return character)
					vim.fn.system(
						string.format("printf '\\r' | wezterm cli send-text --no-paste --pane-id %d", pane_id)
					)
				end
				vim.notify("Sent to right pane " .. pane_id .. " (assuming Claude)", vim.log.levels.INFO)

				-- Focus the right pane if requested (this is same window since it's "right")
				if focus_pane then
					local focus_cmd = string.format("wezterm cli activate-pane --pane-id %d", pane_id)
					vim.fn.system(focus_cmd)
				end

				return
			end
		end
	end

	-- Fallback: copy to clipboard
	vim.fn.setreg("+", text)
	vim.notify("Copied to clipboard - paste in Claude Code with Cmd/Ctrl+V", vim.log.levels.INFO)
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

	-- In normal mode, just return file reference
	if mode == "n" then
		return "@" .. relative_path
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

			-- Check if it's a partial selection (selected text exists and is not the full line)
			local result
			if selected_text and selected_text ~= "" and selected_text:match("%S") then
				-- Always include selected text if it exists and has non-whitespace
				result = string.format("@%s:%d `%s`", relative_path, start_line, selected_text)
			else
				-- Empty or whitespace-only selection
				result = string.format("@%s:%d", relative_path, start_line)
			end
			-- vim.notify("Returning: " .. result, vim.log.levels.INFO)
			return result
		else
			-- Exit visual mode
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

			-- Multiple lines or line-wise visual mode
			if start_line == end_line then
				return string.format("@%s:%d", relative_path, start_line)
			else
				return string.format("@%s:%d-%d", relative_path, start_line, end_line)
			end
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
	local initial_height = 1 -- Start with just 1 line
	local max_height = math.min(20, math.floor(vim.o.lines * 0.4))

	-- Use cursor-relative positioning
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		width = width,
		height = initial_height,
		row = 1,     -- 1 line below cursor
		col = 0,     -- aligned with cursor column
		anchor = "NW", -- northwest corner at the position
		border = "rounded",
		title = " Claude Prompt (Shift+Enter to send, Esc to cancel) ",
		title_pos = "center",
		style = "minimal",
	})

	-- Set initial content with reference and space
	local initial_text = reference .. " "
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_text })

	-- Set buffer options
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	-- Function to resize window based on content
	local function resize_window()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local line_count = #lines

		-- Count wrapped lines if wrap is enabled
		for _, line in ipairs(lines) do
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
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local input = table.concat(lines, "\n")
		vim.api.nvim_win_close(win, true)
		if input and input ~= "" then
			-- Send input with Enter key to execute, but don't focus
			send_to_claude(input, true, false) -- yes enter, no focus
		end
	end, opts)

	-- Shift+Enter to send (in insert mode)
	vim.keymap.set("i", "<S-CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local input = table.concat(lines, "\n")
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
	vim.api.nvim_create_user_command("ClaudeTest", function(opts)
		M.test_send(opts.args)
	end, { nargs = 1, desc = "Test sending to specific WezTerm pane" })
end

return M
