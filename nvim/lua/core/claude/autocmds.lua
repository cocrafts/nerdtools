--- Claude IDE integration autocmds with debounced visual selection tracking
--- Based on claudecode.nvim's proven approach for smooth real-time selection
--- @module 'core.claude.autocmds'

local M = {}

local websocket = require("core.claude.websocket")

-- Debouncing state for visual selection tracking
local selection_timer = nil
local last_visual_selection = nil
local visual_demotion_timer = nil
local buffer_revert_timer = nil
local SELECTION_DEBOUNCE_MS = 100
local VISUAL_DEMOTION_MS = 50
local BUFFER_REVERT_MS = 300 -- Longer delay before reverting to buffer

-- Send notification for current buffer (manual trigger)
function M.notify_current_buffer()
	if not websocket.is_connected() then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)

	if filepath == "" then
		return
	end

	-- Get current cursor position
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]

	-- Send at_mentioned notification with current line
	websocket.send_mention(filepath, nil, line, line)
end

-- Get current visual selection info
local function get_visual_selection()
	local mode = vim.fn.mode()
	if not mode:match("[vV\x16]") then
		-- Not in visual mode, check if we have cached selection from visual demotion
		return last_visual_selection
	end

	local filepath = vim.api.nvim_buf_get_name(0)
	if filepath == "" then
		return nil
	end

	-- Get selection boundaries (cursor and visual start)
	local cursor_pos = vim.fn.getpos(".")
	local visual_pos = vim.fn.getpos("v")

	local start_line = math.min(cursor_pos[2], visual_pos[2])
	local end_line = math.max(cursor_pos[2], visual_pos[2])
	local start_col = math.min(cursor_pos[3], visual_pos[3])
	local end_col = math.max(cursor_pos[3], visual_pos[3])

	-- Get the selected text
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	if #lines == 0 then
		return nil
	end

	-- Handle single line vs multi-line selection
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_col, end_col)
	else
		lines[1] = string.sub(lines[1], start_col)
		lines[#lines] = string.sub(lines[#lines], 1, end_col)
	end

	local text = table.concat(lines, "\n")

	return {
		filepath = filepath,
		text = text,
		start_line = start_line,
		end_line = end_line,
		start_col = start_col - 1, -- Convert to 0-based for MCP
		end_col = end_col - 1,
	}
end

-- Send debounced visual selection update
local function send_selection_update()
	local selection = get_visual_selection()
	if not selection or not websocket.is_connected() then
		return
	end

	-- Send at_mentioned notification
	websocket.send_mention(selection.filepath, selection.text, selection.start_line, selection.end_line)
end

-- Debounced selection tracking (like claudecode.nvim)
local function schedule_selection_update()
	-- Cancel previous timer
	if selection_timer then
		selection_timer:stop()
		selection_timer:close()
		selection_timer = nil
	end

	-- Schedule new update
	selection_timer = vim.loop.new_timer()
	selection_timer:start(SELECTION_DEBOUNCE_MS, 0, vim.schedule_wrap(function()
		send_selection_update()
		if selection_timer then
			selection_timer:close()
			selection_timer = nil
		end
	end))
end

-- Manual trigger for visual selection (for keybinds)
function M.notify_visual_selection()
	send_selection_update()
end

-- Enhanced visual demotion system (smooth transition then buffer revert)
local function start_visual_demotion()
	-- Cancel previous timers
	if visual_demotion_timer then
		visual_demotion_timer:stop()
		visual_demotion_timer:close()
		visual_demotion_timer = nil
	end
	if buffer_revert_timer then
		buffer_revert_timer:stop()
		buffer_revert_timer:close()
		buffer_revert_timer = nil
	end

	-- Cache current selection for smooth transition
	last_visual_selection = get_visual_selection()

	-- Clear cached selection after demotion period (smooth transition)
	visual_demotion_timer = vim.loop.new_timer()
	visual_demotion_timer:start(VISUAL_DEMOTION_MS, 0, vim.schedule_wrap(function()
		last_visual_selection = nil
		if visual_demotion_timer then
			visual_demotion_timer:close()
			visual_demotion_timer = nil
		end
	end))

	-- Revert to buffer view after longer delay (natural UX)
	buffer_revert_timer = vim.loop.new_timer()
	buffer_revert_timer:start(BUFFER_REVERT_MS, 0, vim.schedule_wrap(function()
		if not vim.fn.mode():match("[vV\x16]") then -- Only if still not in visual mode
			M.notify_current_buffer()
		end
		if buffer_revert_timer then
			buffer_revert_timer:close()
			buffer_revert_timer = nil
		end
	end))
end

-- Setup debounced visual selection tracking
function M.setup()
	local augroup = vim.api.nvim_create_augroup("ClaudeIDE", { clear = true })

	-- File open/save notifications
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
		group = augroup,
		callback = function()
			if not websocket.is_connected() then
				return
			end
			-- Delay slightly to not block file operations
			vim.defer_fn(M.notify_current_buffer, 100)
		end,
		desc = "Notify Claude Code on file open/save",
	})

	-- Debounced cursor movement tracking in visual mode
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = augroup,
		callback = function()
			if not websocket.is_connected() then
				return
			end

			local mode = vim.fn.mode()
			if mode:match("[vV\x16]") then
				-- In visual mode, schedule debounced update
				schedule_selection_update()
			end
		end,
		desc = "Debounced visual selection tracking",
	})

	-- Handle leaving visual mode (enhanced visual demotion)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = augroup,
		pattern = "[vV\x16]*:*", -- Leaving any visual mode
		callback = function()
			if not websocket.is_connected() then
				return
			end
			-- Start enhanced visual demotion (smooth transition + eventual buffer revert)
			start_visual_demotion()
		end,
		desc = "Enhanced visual demotion with buffer revert",
	})

	-- Create user commands for manual triggering
	vim.api.nvim_create_user_command("ClaudeSendBuffer", M.notify_current_buffer, {
		desc = "Send current buffer to Claude Code",
	})

	vim.api.nvim_create_user_command("ClaudeSendSelection", M.notify_visual_selection, {
		range = true,
		desc = "Send visual selection to Claude Code",
	})

	-- Optional keybindings (users can customize)
	-- vim.keymap.set("n", "<leader>cb", M.notify_current_buffer, { desc = "Send buffer to Claude" })
	-- vim.keymap.set("v", "<leader>cs", M.notify_visual_selection, { desc = "Send selection to Claude" })
end

return M