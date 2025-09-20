--- Shared utilities for Claude integration
--- @module 'core.claude.utils'

local M = {}

-- Helper to escape text for shell commands
function M.escape_shell_text(text)
	if not text then
		return ""
	end
	return text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("`", "\\`")
end

-- Get project root (git root or current directory)
function M.get_project_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
	if vim.v.shell_error == 0 and git_root ~= "" then
		return git_root
	end
	return vim.fn.getcwd()
end

-- Make path relative to project root
function M.make_relative_path(filepath)
	if not filepath or filepath == "" then
		return nil
	end

	local project_root = M.get_project_root()
	local absolute_path = vim.fn.fnamemodify(filepath, ":p")

	-- Check if file is within project root
	if absolute_path:sub(1, #project_root) == project_root then
		local relative = absolute_path:sub(#project_root + 2) -- +2 to skip trailing slash
		return relative
	end

	-- Return basename if outside project
	return vim.fn.fnamemodify(filepath, ":t")
end

-- Check if we're in WezTerm
function M.is_wezterm()
	return os.getenv("TERM_PROGRAM") == "WezTerm" and os.getenv("WEZTERM_PANE") ~= nil
end

-- Get current WezTerm pane ID
function M.get_current_pane_id()
	local pane_id = os.getenv("WEZTERM_PANE")
	if pane_id then
		return tonumber(pane_id)
	end
	return nil
end

-- Execute command and return result
function M.execute_command(cmd)
	local result = vim.fn.system(cmd)
	local success = vim.v.shell_error == 0
	return success, result
end

-- Parse JSON safely
function M.parse_json(json_str)
	if not json_str or json_str == "" then
		return nil, "Empty JSON string"
	end

	local ok, result = pcall(vim.json.decode, json_str)
	if ok then
		return result, nil
	else
		return nil, "Failed to parse JSON: " .. tostring(result)
	end
end

-- Debounce function
function M.debounce(fn, delay_ms)
	local timer = nil
	return function(...)
		local args = { ... }
		if timer then
			vim.loop.timer_stop(timer)
			vim.loop.close(timer)
		end
		timer = vim.loop.new_timer()
		vim.loop.timer_start(timer, delay_ms, 0, function()
			vim.loop.close(timer)
			timer = nil
			vim.schedule(function()
				fn(unpack(args))
			end)
		end)
	end
end

-- Get visual selection text
function M.get_visual_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then -- \22 is Ctrl-V
		return nil
	end

	-- Get selection boundaries
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	-- Ensure start is before end
	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	-- Get the selected text
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

	if #lines == 0 then
		return nil
	end

	-- Handle partial line selection
	if #lines == 1 then
		return lines[1]:sub(start_col, end_col)
	else
		-- First line: from start_col to end
		lines[1] = lines[1]:sub(start_col)
		-- Last line: from beginning to end_col
		lines[#lines] = lines[#lines]:sub(1, end_col)
		return table.concat(lines, "\n")
	end
end

-- Format file reference with optional line numbers
function M.format_file_reference(filepath, start_line, end_line)
	local relative_path = M.make_relative_path(filepath)
	if not relative_path then
		return nil
	end

	local reference = "@" .. relative_path

	if start_line then
		if end_line and end_line ~= start_line then
			reference = reference .. ":" .. start_line .. "-" .. end_line
		else
			reference = reference .. ":" .. start_line
		end
	end

	return reference
end

-- Check if buffer is a special buffer (not a regular file)
function M.is_special_buffer(bufnr)
	bufnr = bufnr or 0
	local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

	-- Check buffer type
	if buftype ~= "" and buftype ~= "help" then
		return true
	end

	-- Check known special filetypes
	local special_filetypes = {
		"neo-tree",
		"neo-tree-popup",
		"NvimTree",
		"oil",
		"minifiles",
		"aerial",
		"tagbar",
		"toggleterm",
	}

	for _, ft in ipairs(special_filetypes) do
		if filetype == ft then
			return true
		end
	end

	return false
end

-- Create autocmd group
function M.create_augroup(name)
	return vim.api.nvim_create_augroup("Claude_" .. name, { clear = true })
end

-- Log helper
function M.log(level, msg, ...)
	local config = require("core.claude.config")
	if config.is_debug() then
		local formatted = string.format(msg, ...)
		vim.notify("[Claude] " .. formatted, level)
	end
end

-- Timer management
function M.create_timer(callback, delay_ms, repeat_ms)
	local timer = vim.loop.new_timer()
	if not timer then
		return nil
	end

	vim.loop.timer_start(timer, delay_ms, repeat_ms or 0, function()
		vim.schedule(callback)
	end)

	return timer
end

function M.stop_timer(timer)
	if timer then
		vim.loop.timer_stop(timer)
		vim.loop.close(timer)
	end
end

-- File operations
function M.read_file(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return content
end

function M.write_file(path, content)
	local file = io.open(path, "w")
	if not file then
		return false
	end
	file:write(content)
	file:close()
	return true
end

-- Table utilities
function M.tbl_contains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

function M.tbl_keys(tbl)
	local keys = {}
	for k, _ in pairs(tbl) do
		table.insert(keys, k)
	end
	return keys
end

return M