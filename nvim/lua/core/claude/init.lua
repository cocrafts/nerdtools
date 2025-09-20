--- Claude Code integration for Neovim
--- Provides seamless integration with Claude Code CLI
--- @module 'core.claude'

local M = {}

-- Load submodules
local config = require("core.claude.config")
local utils = require("core.claude.utils")
local wezterm = require("core.claude.wezterm")
local session = require("core.claude.session")
local ui = require("core.claude.ui")
local ide = require("core.claude.ide")
local mention = require("core.claude.mention")

-- Helper function to get visual selection info
local function get_visual_selection_info(filepath)
	local reference = "@" .. utils.make_relative_path(filepath)
	local selected_text = nil

	-- Check for visual selection
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then -- \22 is Ctrl-V
		-- Get selection boundaries
		local start_pos = vim.fn.getpos("v")
		local end_pos = vim.fn.getpos(".")
		local start_line = start_pos[2]
		local end_line = end_pos[2]

		-- Ensure start is before end
		if start_line > end_line then
			start_line, end_line = end_line, start_line
			start_pos, end_pos = end_pos, start_pos
		end

		-- Add line range to reference
		if start_line == end_line then
			reference = reference .. ":" .. start_line
		else
			reference = reference .. ":" .. start_line .. "-" .. end_line
		end

		-- Get the actual selected text
		if mode == "V" then
			-- Line-wise visual mode
			selected_text = table.concat(
				vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false),
				"\n"
			)
		elseif mode == "v" then
			-- Character-wise visual mode
			if start_line == end_line then
				-- Single line selection
				local line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
				if line then
					local start_col = start_pos[3]
					local end_col = end_pos[3]
					if start_col > end_col then
						start_col, end_col = end_col, start_col
					end
					selected_text = line:sub(start_col, end_col)
				end
			else
				-- Multi-line character selection
				local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
				if #lines > 0 then
					-- First line: from start_col to end
					lines[1] = lines[1]:sub(start_pos[3])
					-- Last line: from beginning to end_col
					lines[#lines] = lines[#lines]:sub(1, end_pos[3])
					selected_text = table.concat(lines, "\n")
				end
			end
		elseif mode == "\22" then
			-- Block-wise visual mode
			local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
			local start_col = math.min(start_pos[3], end_pos[3])
			local end_col = math.max(start_pos[3], end_pos[3])
			local block_lines = {}
			for _, line in ipairs(lines) do
				table.insert(block_lines, line:sub(start_col, end_col))
			end
			selected_text = table.concat(block_lines, "\n")
		end
	end

	return reference, selected_text
end

-- Setup function
function M.setup(opts)
	-- Setup configuration first
	if not config.setup(opts) then
		return false
	end

	-- Initialize submodules
	wezterm.setup()
	session.setup()
	ui.setup()
	ide.setup()

	-- Load status commands
	require("core.claude.status")

	-- Setup diagnostics monitoring
	require("core.claude.diagnostics").setup()

	-- Create keymaps
	local keymaps = config.get("keymaps")
	if keymaps and keymaps.send then
		vim.keymap.set({ "n", "v" }, keymaps.send, M.smart_send, { desc = "Send to Claude" })
	end
	if keymaps and keymaps.send_with_prompt then
		vim.keymap.set({ "n", "v" }, keymaps.send_with_prompt, M.smart_send_with_prompt, { desc = "Send to Claude with prompt" })
	end
	if keymaps and keymaps.focus_claude then
		vim.keymap.set("n", keymaps.focus_claude, M.focus_claude, { desc = "Focus Claude terminal" })
	end

	return true
end

-- Smart send to Claude (WebSocket first, then WezTerm)
function M.smart_send()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end

	local reference, selected_text = get_visual_selection_info(filepath)

	-- Extract line numbers
	local line_start, line_end
	if reference:match(":(%d+)-(%d+)$") then
		line_start = tonumber(reference:match(":(%d+)"))
		line_end = tonumber(reference:match("-(%d+)$"))
	elseif reference:match(":(%d+)$") then
		line_start = tonumber(reference:match(":(%d+)$"))
		line_end = line_start
	end

	-- Try WebSocket first
	if ide.is_connected() then
		if ide.send_to_claude(filepath, selected_text or "", line_start, line_end) then
			vim.notify("Sent to Claude via IDE", vim.log.levels.INFO)
			return
		end
	end

	-- Fall back to WezTerm
	if wezterm.has_claude_pane() then
		-- Process any queued mentions first
		if mention.has_pending() then
			local processed = mention.process_queue(function(fp, text, ls, le)
				return ide.send_to_claude(fp, text or "", ls, le)
			end)
			if processed > 0 then
				vim.notify("Sent " .. processed .. " queued mentions", vim.log.levels.INFO)
			end
		end

		-- Send via WezTerm
		reference = reference .. " "
		if selected_text then
			reference = reference .. "\n\n" .. selected_text
		end
		wezterm.send_to_claude(reference, false, config.get("focus_after_send"))
	else
		-- Queue for later
		mention.queue(filepath, selected_text, line_start, line_end)
		vim.notify("Claude not connected. Queued (" .. mention.size() .. " pending)", vim.log.levels.INFO)
	end
end

-- Smart send with prompt using floating window
function M.smart_send_with_prompt()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end

	local reference, selected_text = get_visual_selection_info(filepath)

	-- Build the initial prompt with reference and selected text
	local initial_prompt = reference .. " "
	if selected_text then
		initial_prompt = initial_prompt .. "\n\nSelected text:\n```\n" .. selected_text .. "\n```\n\n"
	end

	-- Use floating window prompt from ui module
	ui.show_prompt_window(initial_prompt, function(input)
		if input and input ~= "" then
			-- Extract line numbers
			local line_start, line_end
			if reference:match(":(%d+)-(%d+)$") then
				line_start = tonumber(reference:match(":(%d+)"))
				line_end = tonumber(reference:match("-(%d+)$"))
			elseif reference:match(":(%d+)$") then
				line_start = tonumber(reference:match(":(%d+)$"))
				line_end = line_start
			end

			-- Combine text
			local full_text = input
			if selected_text then
				full_text = selected_text .. "\n\n" .. input
			end

			-- Try WebSocket first
			if ide.is_connected() then
				if ide.send_to_claude(filepath, full_text, line_start, line_end) then
					vim.notify("Sent to Claude via IDE", vim.log.levels.INFO)
					return
				end
			end

			-- Fall back to WezTerm
			if wezterm.has_claude_pane() then
				wezterm.send_to_claude(full_text, true, config.get("focus_after_send"))
			else
				mention.queue(filepath, full_text, line_start, line_end)
				vim.notify("Claude not connected. Queued.", vim.log.levels.INFO)
			end
		end
	end)
end

-- Focus Claude terminal
function M.focus_claude()
	wezterm.focus_claude_pane()
end

-- Process queued mentions when Claude connects
function M.process_pending_mentions()
	if mention.has_pending() then
		local send_func = ide.is_connected() and ide.send_to_claude or function(fp, text, ls, le)
			local ref = "@" .. utils.make_relative_path(fp)
			if ls and le then
				ref = ref .. ":" .. ls
				if ls ~= le then
					ref = ref .. "-" .. le
				end
			end
			if text and text ~= "" then
				ref = ref .. "\n" .. text
			end
			return wezterm.send_to_claude(ref, false, false)
		end

		local processed = mention.process_queue(send_func)
		if processed > 0 then
			vim.notify("Processed " .. processed .. " queued mentions", vim.log.levels.INFO)
		end
	end
end

return M