---@brief Enhanced selection tracking for Claude IDE
---@module 'plugins.claude.selection'

local M = {}

local server = nil -- Lazy load to avoid circular dependency

-- Selection state
local state = {
	latest_selection = nil,
	tracking_enabled = false,
	debounce_timer = nil,
	debounce_ms = 50, -- Faster for better responsiveness

	last_active_visual_selection = nil,
	demotion_timer = nil,
	visual_demotion_delay_ms = 100, -- Keep visual selection briefly after leaving visual mode
}

--- Enable selection tracking
---@param srv table Server instance
function M.enable(srv)
	if state.tracking_enabled then
		return
	end

	state.tracking_enabled = true
	server = srv
	M._create_autocommands()
	-- Selection tracking enabled
end

--- Disable selection tracking
function M.disable()
	if not state.tracking_enabled then
		return
	end

	state.tracking_enabled = false
	M._clear_autocommands()

	-- Stop all timers
	if state.debounce_timer then
		vim.loop.timer_stop(state.debounce_timer)
		state.debounce_timer = nil
	end

	if state.demotion_timer then
		state.demotion_timer:stop()
		state.demotion_timer:close()
		state.demotion_timer = nil
	end

	state.latest_selection = nil
	state.last_active_visual_selection = nil
	server = nil

	-- Selection tracking disabled
end

--- Create autocommands for tracking
function M._create_autocommands()
	local group = vim.api.nvim_create_augroup("ClaudeSelection", { clear = true })

	-- Track cursor movement
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			M.on_cursor_moved()
		end,
		desc = "Track cursor movement for Claude IDE",
	})

	-- Track mode changes (especially important for visual mode)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			M.on_mode_changed()
		end,
		desc = "Track mode changes for Claude IDE",
	})

	-- Track text changes
	vim.api.nvim_create_autocmd("TextChanged", {
		group = group,
		callback = function()
			M.on_text_changed()
		end,
		desc = "Track text changes for Claude IDE",
	})
end

--- Clear autocommands
function M._clear_autocommands()
	vim.api.nvim_clear_autocmds({ group = "ClaudeSelection" })
end

--- Handle cursor movement
function M.on_cursor_moved()
	M.debounce_update()
end

--- Handle mode change
function M.on_mode_changed()
	-- Immediate update on mode change for better responsiveness
	M.update_selection()
end

--- Handle text change
function M.on_text_changed()
	M.debounce_update()
end

--- Debounce selection updates
function M.debounce_update()
	if state.debounce_timer then
		vim.loop.timer_stop(state.debounce_timer)
	end

	state.debounce_timer = vim.defer_fn(function()
		M.update_selection()
		state.debounce_timer = nil
	end, state.debounce_ms)
end

--- Get visual selection details
---@return table|nil
function M.get_visual_selection()
	local mode = vim.api.nvim_get_mode().mode

	-- Check if we're in any visual mode
	if not (mode == "v" or mode == "V" or mode == "\22") then
		return nil
	end

	-- Get selection anchors
	local fixed_anchor = vim.fn.getpos("v")
	local cursor = vim.api.nvim_win_get_cursor(0)

	if fixed_anchor[2] == 0 then
		return nil -- No valid visual mark
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(current_buf)

	-- Convert positions to start/end
	local p1 = { line = fixed_anchor[2], col = fixed_anchor[3] }
	local p2 = { line = cursor[1], col = cursor[2] + 1 }

	-- Ensure start comes before end
	local start_pos, end_pos
	if p1.line < p2.line or (p1.line == p2.line and p1.col <= p2.col) then
		start_pos, end_pos = p1, p2
	else
		start_pos, end_pos = p2, p1
	end

	-- Get the selected text
	local lines = vim.api.nvim_buf_get_lines(current_buf, start_pos.line - 1, end_pos.line, false)

	if #lines == 0 then
		return nil
	end

	local text
	if mode == "V" then
		-- Line-wise selection
		text = table.concat(lines, "\n")
		start_pos.col = 1
		if #lines > 0 then
			end_pos.col = #lines[#lines]
		end
	elseif mode == "v" then
		-- Character-wise selection
		if #lines == 1 then
			text = lines[1]:sub(start_pos.col, end_pos.col)
		else
			local parts = {}
			parts[1] = lines[1]:sub(start_pos.col)
			for i = 2, #lines - 1 do
				parts[i] = lines[i]
			end
			parts[#lines] = lines[#lines]:sub(1, end_pos.col)
			text = table.concat(parts, "\n")
		end
	elseif mode == "\22" then
		-- Block-wise selection
		local parts = {}
		for _, line in ipairs(lines) do
			table.insert(parts, line:sub(start_pos.col, end_pos.col))
		end
		text = table.concat(parts, "\n")
	end

	return {
		text = text or "",
		filePath = file_path,
		fileUrl = "file://" .. file_path,
		selection = {
			start = {
				line = start_pos.line - 1, -- Convert to 0-indexed
				character = start_pos.col - 1,
			},
			["end"] = {
				line = end_pos.line - 1,
				character = end_pos.col,
			},
			isEmpty = not text or #text == 0,
		},
	}
end

--- Get cursor position (no selection)
---@return table
function M.get_cursor_position()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_buf = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(current_buf)

	return {
		text = "",
		filePath = file_path,
		fileUrl = "file://" .. file_path,
		selection = {
			start = { line = cursor[1] - 1, character = cursor[2] },
			["end"] = { line = cursor[1] - 1, character = cursor[2] },
			isEmpty = true,
		},
	}
end

--- Check if selection has changed
---@param new_selection table|nil
---@return boolean
function M.has_selection_changed(new_selection)
	local old = state.latest_selection

	if not new_selection then
		return old ~= nil
	end

	if not old then
		return true
	end

	-- Compare key fields
	if old.filePath ~= new_selection.filePath then
		return true
	end

	if old.text ~= new_selection.text then
		return true
	end

	if
		old.selection.start.line ~= new_selection.selection.start.line
		or old.selection.start.character ~= new_selection.selection.start.character
		or old.selection["end"].line ~= new_selection.selection["end"].line
		or old.selection["end"].character ~= new_selection.selection["end"].character
	then
		return true
	end

	return false
end

--- Update selection state
function M.update_selection()
	if not state.tracking_enabled then
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(current_buf)

	-- Skip special buffers
	if buf_name:match("^%[") or vim.bo.buftype ~= "" then
		return
	end

	local mode = vim.api.nvim_get_mode().mode
	local current_selection

	if mode == "v" or mode == "V" or mode == "\22" then
		-- In visual mode - cancel any pending demotion
		if state.demotion_timer then
			state.demotion_timer:stop()
			state.demotion_timer:close()
			state.demotion_timer = nil
		end

		current_selection = M.get_visual_selection()

		if current_selection then
			state.last_active_visual_selection = {
				bufnr = current_buf,
				selection_data = vim.deepcopy(current_selection),
				timestamp = vim.loop.now(),
			}
		end
	else
		-- Not in visual mode
		local last_visual = state.last_active_visual_selection

		if last_visual and last_visual.bufnr == current_buf and not state.demotion_timer then
			-- Just left visual mode - keep selection briefly
			current_selection = state.latest_selection -- Keep the visual selection

			-- Start demotion timer
			state.demotion_timer = vim.loop.new_timer()
			state.demotion_timer:start(
				state.visual_demotion_delay_ms,
				0,
				vim.schedule_wrap(function()
					if state.demotion_timer then
						state.demotion_timer:stop()
						state.demotion_timer:close()
						state.demotion_timer = nil
					end
					M.handle_selection_demotion(current_buf)
				end)
			)
		else
			-- Normal mode, no recent visual
			current_selection = M.get_cursor_position()
			if last_visual and last_visual.bufnr == current_buf then
				state.last_active_visual_selection = nil
			end
		end
	end

	if not current_selection then
		current_selection = M.get_cursor_position()
	end

	-- Check if selection changed
	if M.has_selection_changed(current_selection) then
		state.latest_selection = current_selection
		M.send_selection_update(current_selection)
	end
end

--- Handle demotion of visual selection after delay
---@param original_bufnr number
function M.handle_selection_demotion(original_bufnr)
	local current_buf = vim.api.nvim_get_current_buf()
	local mode = vim.api.nvim_get_mode().mode

	-- If we're back in visual mode, don't demote
	if mode == "v" or mode == "V" or mode == "\22" then
		if state.last_active_visual_selection and state.last_active_visual_selection.bufnr == original_bufnr then
			state.last_active_visual_selection = nil
		end
		return
	end

	-- Still in same buffer and normal mode - demote to cursor position
	if current_buf == original_bufnr then
		local cursor_selection = M.get_cursor_position()
		if M.has_selection_changed(cursor_selection) then
			state.latest_selection = cursor_selection
			M.send_selection_update(cursor_selection)
		end
	end

	-- Clear last visual selection for this buffer
	if state.last_active_visual_selection and state.last_active_visual_selection.bufnr == original_bufnr then
		state.last_active_visual_selection = nil
	end
end

--- Send selection update to Claude
---@param selection table
function M.send_selection_update(selection)
	if not server then
		server = require("plugins.claude.server")
	end

	if server and server.send_selection_changed then
		server.send_selection_changed(selection)
		-- Selection updated
	end
end

--- Get latest selection
---@return table|nil
function M.get_latest_selection()
	return state.latest_selection
end

--- Setup selection tracking with server
---@param srv table|nil Optional server instance
function M.setup(srv)
	-- Store server if provided
	if srv then
		M.enable(srv)
	else
		-- Just create the module structure, enable will be called later
		-- Selection module initialized
	end
end

return M
