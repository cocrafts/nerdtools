--- Minimal Claude session tracking
--- @module 'core.claude.session'

local M = {}
local utils = require("core.claude.utils")
local config = require("core.claude.config")

-- Read active Claude sessions from tracking file
function M.read_claude_sessions()
	local sessions = {}
	local tracking_file = config.get("tracking_file")
	if not tracking_file then
		return sessions
	end

	local content = utils.read_file(tracking_file)
	if not content then
		return sessions
	end

	for line in content:gmatch("[^\r\n]+") do
		local parts = {}
		for part in line:gmatch("[^:]+") do
			table.insert(parts, part)
		end

		if #parts >= 5 then
			local session_id = parts[1]
			local dir = parts[2]
			local timestamp = parts[3] .. ":" .. parts[4] .. ":" .. parts[5]
			local claude_pid = parts[6]

			table.insert(sessions, {
				id = session_id,
				dir = dir,
				timestamp = timestamp,
				claude_pid = claude_pid and tonumber(claude_pid) or nil,
			})
		end
	end

	return sessions
end

-- Find Claude session matching current directory
function M.find_matching_session()
	local current_dir = utils.get_project_root()
	local sessions = M.read_claude_sessions()

	for _, session in ipairs(sessions) do
		if session.dir == current_dir then
			return session
		end
	end

	return nil
end

-- Get all Claude panes from WezTerm
function M.get_claude_panes()
	if not utils.is_wezterm() then
		return {}
	end

	local success, result = utils.execute_command("wezterm cli list --format json")
	if not success then
		return {}
	end

	local panes, err = utils.parse_json(result)
	if not panes or err then
		return {}
	end

	local claude_panes = {}
	for _, pane in ipairs(panes) do
		if pane.foreground_process_name == "claude" then
			local pane_cwd = pane.cwd and pane.cwd:gsub("^file://[^/]+", "") or nil
			table.insert(claude_panes, {
				pane_id = pane.pane_id,
				window_id = pane.window_id,
				title = pane.title,
				cwd = pane_cwd,
			})
		end
	end

	return claude_panes
end

-- Setup function
function M.setup()
	local tracking_file = config.get("tracking_file")
	if tracking_file then
		local dir = vim.fn.fnamemodify(tracking_file, ":h")
		vim.fn.mkdir(dir, "p")
	end
end

return M