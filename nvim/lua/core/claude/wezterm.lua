--- WezTerm integration for Claude Code
--- Handles sending text to Claude in WezTerm panes
--- @module 'core.claude.wezterm'

local M = {}
local ui = nil -- Lazy load to avoid circular dependency

-- Helper for status display
local function show_status(msg, timeout)
	if not ui then
		ui = require("core.claude.ui")
	end
	ui.show_status(msg, timeout)
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
	local session = require("core.claude.session")
	local claude_sessions = session.read_claude_sessions()

	-- First priority: Check sessions that match current directory
	local current_dir = vim.fn.getcwd()

	-- Look for session matching current directory
	for _, sess in ipairs(claude_sessions) do
		if sess.pane_id and sess.dir == current_dir then
			-- Verify this pane still exists in the correct window
			for _, pane in ipairs(panes) do
				if pane.pane_id == sess.pane_id and pane.pane_id ~= current_pane then
					-- If we have window_id in session, verify it matches
					if sess.window_id and pane.window_id ~= sess.window_id then
						-- Wrong window, skip
					else
						-- Found the exact pane from session tracking!
						return pane.pane_id, pane.window_id
					end
				end
			end
		end
	end

	-- Second priority: Look for ✳ emoji in title AND matching directory
	local claude_candidates = {}

	for _, pane in ipairs(panes) do
		if pane.pane_id ~= current_pane and pane.title then
			-- Claude Code uses ✳ emoji in its terminal display
			if pane.title:match("✳") then
				local pane_dir = pane.cwd and pane.cwd:gsub("^file://[^/]+", "") or ""

				-- Check if it matches current directory
				if pane_dir == current_dir then
					-- Perfect match - same directory
					return pane.pane_id, pane.window_id
				end

				-- Store as candidate if it's in a related directory
				if pane_dir:find(current_dir, 1, true) or current_dir:find(pane_dir, 1, true) then
					table.insert(claude_candidates, {pane_id = pane.pane_id, window_id = pane.window_id, dir = pane_dir})
				end
			end
		end
	end

	-- If we have candidates, return the first one (could be improved with better heuristics)
	if #claude_candidates > 0 then
		return claude_candidates[1].pane_id, claude_candidates[1].window_id
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

-- Send text to Claude (WezTerm or clipboard)
function M.send_to_claude(text, send_enter, focus_pane)
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

					if focus_pane then
						-- Just try to activate the pane
						vim.fn.system(string.format("wezterm cli activate-pane --pane-id %d", claude_pane_id))
					end
				else
					show_status("Failed: " .. err, 3000)
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
	show_status("Claude Code panel does not exist", 3000)
end

-- Focus Claude pane if found
function M.focus_claude_pane()
	if os.getenv("TERM_PROGRAM") ~= "WezTerm" or not os.getenv("WEZTERM_PANE") then
		show_status("Not in WezTerm")
		return
	end

	local current_pane = tonumber(os.getenv("WEZTERM_PANE"))
	local panes_json = vim.fn.system("wezterm cli list --format json")

	if vim.v.shell_error == 0 then
		local ok, panes = pcall(vim.json.decode, panes_json)
		if ok and panes and #panes > 0 then
			local claude_pane_id, claude_window_id = find_claude_pane(panes, current_pane)

			if claude_pane_id then
				-- Find current window
				local current_window_id
				for _, pane in ipairs(panes) do
					if pane.pane_id == current_pane then
						current_window_id = pane.window_id
						break
					end
				end

				if claude_window_id == current_window_id then
					vim.fn.system(string.format("wezterm cli activate-pane --pane-id %d", claude_pane_id))
					show_status(string.format("Focused pane %d", claude_pane_id))
				else
					show_status(string.format("Claude is in window %d (different window)", claude_window_id))
				end
			else
				show_status("No Claude pane found")
			end
		end
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

	-- Test different sending methods
	local cmd1 = string.format('printf "Test 1: Using printf" | wezterm cli send-text --pane-id %d', pane_id)
	vim.fn.system(cmd1)
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	vim.fn.system(string.format('wezterm cli send-text --pane-id %d "Test 2: Direct text"', pane_id))
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	local multiline = "Test 3: Line 1\\nTest 3: Line 2"
	local cmd3 = string.format('printf "%s" | wezterm cli send-text --pane-id %d', multiline, pane_id)
	vim.fn.system(cmd3)
	vim.fn.system(string.format('wezterm cli send-text --pane-id %d $"\\r"', pane_id))

	print("Test messages sent. Check pane " .. pane_id)
end

-- List WezTerm panes (detailed debug)
function M.list_panes()
	local panes_json = vim.fn.system("wezterm cli list --format json")
	if vim.v.shell_error == 0 then
		local ok, panes = pcall(vim.json.decode, panes_json)
		if ok and panes then
			local current_pane = tonumber(os.getenv("WEZTERM_PANE"))
			local project_root = session.get_project_root()
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
					local claude_sessions = session.read_claude_sessions()
					local claude_dirs = {}
					for _, sess in ipairs(claude_sessions) do
						claude_dirs[sess.dir] = true
					end

					-- Check if Claude is actively running (by title pattern)
					-- Claude Code consistently uses ✳ in its display
					if pane.title and pane.title:match("✳") then
						is_claude = true
						table.insert(markers, "active")
					end

					-- Check session directory match
					if is_claude and pane.cwd then
						local pane_dir = pane.cwd:gsub("^file://[^/]+", "")
						if claude_dirs[pane_dir] then
							table.insert(markers, "session")
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

-- Check if Claude pane exists
function M.has_claude_pane()
	local panes = get_wezterm_panes()
	if not panes then
		return false
	end

	for _, pane in ipairs(panes) do
		if pane.foreground_process_name == "claude" then
			return true
		end
	end
	return false
end

function M.setup(config)
	-- No specific setup needed for wezterm module yet
end

return M