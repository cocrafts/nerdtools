local M = {}
local icons = require("utils.icons")

local is_ft = function(b, ft)
	return vim.bo[b].filetype == ft
end

local diagnostics_indicator = function(_, _, diagnostics, _)
	local result = {}
	local symbols = {
		error = icons.diagnostics.Error,
		warning = icons.diagnostics.Warning,
		info = icons.diagnostics.Information,
	}

	for name, count in pairs(diagnostics) do
		if symbols[name] and count > 0 then
			table.insert(result, symbols[name] .. " " .. count)
		end
	end

	---@diagnostic disable-next-line: cast-local-type
	result = table.concat(result, " ")
	return #result > 0 and result or ""
end

local custom_filter = function(buf, buf_nums)
	local logs = vim.tbl_filter(function(b)
		return is_ft(b, "log")
	end, buf_nums or {})

	if vim.tbl_isempty(logs) then
		return true
	end

	local tab_num = vim.fn.tabpagenr()
	local last_tab = vim.fn.tabpagenr("$")
	local is_log = is_ft(buf, "log")

	if last_tab == 1 then
		return true
	end
	return (tab_num == last_tab and is_log) or (tab_num ~= last_tab and not is_log)
end

-- Common kill function for bdelete and bwipeout
-- credits: based on bbye and nvim-bufdel
---@param kill_command? string defaults to "bd"
---@param bufnr? number defaults to the current buffer
---@param force? boolean defaults to false
function M.buf_kill(kill_command, bufnr, force)
	kill_command = kill_command or "bd"

	local bo = vim.bo
	local api = vim.api
	local fmt = string.format
	local fnamemodify = vim.fn.fnamemodify

	if bufnr == 0 or bufnr == nil then
		bufnr = api.nvim_get_current_buf()
	end

	local bufname = api.nvim_buf_get_name(bufnr)

	if not force then
		local warning
		if bo[bufnr].modified then
			warning = fmt([[No write since last change for (%s)]], fnamemodify(bufname, ":t"))
		elseif api.nvim_get_option_value("buftype", { buf = bufnr }) == "terminal" then
			warning = fmt([[Terminal %s will be killed]], bufname)
		end
		if warning then
			vim.ui.input({
				prompt = string.format([[%s. Close it anyway? [y]es or [n]o (default: no): ]], warning),
			}, function(choice)
				if choice ~= nil and choice:match("ye?s?") then
					M.buf_kill(kill_command, bufnr, true)
				end
			end)
			return
		end
	end

	-- Get list of windows IDs with the buffer to close
	local windows = vim.tbl_filter(function(win)
		return api.nvim_win_get_buf(win) == bufnr
	end, api.nvim_list_wins())

	if force then
		kill_command = kill_command .. "!"
	end

	-- Get list of active buffers
	local buffers = vim.tbl_filter(function(buf)
		return api.nvim_buf_is_valid(buf) and bo[buf].buflisted
	end, api.nvim_list_bufs())

	-- If there is only one buffer (which has to be the current one), vim will
	-- create a new buffer on :bd.
	-- For more than one buffer, pick the previous buffer (wrapping around if necessary)
	if #buffers > 1 and #windows > 0 then
		for i, v in ipairs(buffers) do
			if v == bufnr then
				local prev_buf_idx = i == 1 and #buffers or (i - 1)
				local prev_buffer = buffers[prev_buf_idx]
				for _, win in ipairs(windows) do
					api.nvim_win_set_buf(win, prev_buffer)
				end
			end
		end
	end

	-- Check if buffer still exists, to ensure the target buffer wasn't killed
	-- due to options like bufhidden=wipe.
	if api.nvim_buf_is_valid(bufnr) and bo[bufnr].buflisted then
		vim.cmd(string.format("%s %d", kill_command, bufnr))
	end
end

local options = {
	mode = "buffers", -- set to "tabs" to only show tabpages instead
	numbers = "ordinal", -- can be "none" | "ordinal" | "buffer_id" | "both" | function
	close_command = function(bufnr) -- can be a string | function, see "Mouse actions"
		M.buf_kill("bd", bufnr, false)
	end,
	right_mouse_command = "vert sbuffer %d", -- can be a string | function, see "Mouse actions"
	left_mouse_command = "buffer %d", -- can be a string | function, see "Mouse actions"
	middle_mouse_command = nil, -- can be a string | function, see "Mouse actions
	indicator = {
		icon = icons.ui.BoldLineLeft, -- this should be omitted if indicator style is not 'icon'
		style = "icon", -- can also be 'underline'|'none',
	},
	buffer_close_icon = icons.ui.Close,
	modified_icon = icons.ui.Circle,
	close_icon = icons.ui.BoldClose,
	left_trunc_marker = icons.ui.ArrowCircleLeft,
	right_trunc_marker = icons.ui.ArrowCircleRight,
	--- name_formatter can be used to change the buffer's label in the bufferline.
	--- Please note some names can/will break the
	--- bufferline so use this at your discretion knowing that it has
	--- some limitations that will *NOT* be fixed.
	name_formatter = function(buf) -- buf contains a "name", "path" and "bufnr"
		-- remove extension from markdown files for example
		if buf.name:match("%.md") then
			return vim.fn.fnamemodify(buf.name, ":t:r")
		end
	end,
	max_name_length = 18,
	max_prefix_length = 15, -- prefix used when a buffer is de-duplicated
	truncate_names = true, -- whether or not tab names should be truncated
	tab_size = 18,
	diagnostics = "nvim_lsp",
	diagnostics_update_in_insert = false,
	diagnostics_indicator = diagnostics_indicator,
	-- NOTE: this will be called a lot so don't do any heavy processing here
	custom_filter = custom_filter,
	offsets = {
		{
			filetype = "undotree",
			text = "Undotree",
			highlight = "PanelHeading",
			padding = 1,
		},
		{
			filetype = "neo-tree",
			text = "File Explorer",
			highlight = "PanelHeading",
			padding = 1,
		},
		{
			filetype = "NvimTree",
			text = "Explorer",
			highlight = "PanelHeading",
			padding = 1,
		},
		{
			filetype = "DiffviewFiles",
			text = "Diff View",
			highlight = "PanelHeading",
			padding = 1,
		},
		{
			filetype = "flutterToolsOutline",
			text = "Flutter Outline",
			highlight = "PanelHeading",
		},
		{
			filetype = "lazy",
			text = "Lazy",
			highlight = "PanelHeading",
			padding = 1,
		},
	},
	color_icons = true, -- whether or not to add the filetype icon highlights
	show_buffer_icons = true,
	show_buffer_close_icons = true,
	show_close_icon = false,
	show_tab_indicators = true,
	persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
	-- can also be a table containing 2 custom separators
	-- [focused and unfocused]. eg: { '|', '|' }
	separator_style = "thin", -- "slant" | "slope" | "thick" | "thin" | { 'any', 'any' },
	enforce_regular_tabs = false,
	always_show_bufferline = true,
	hover = {
		enabled = false, -- requires nvim 0.8+
		delay = 200,
		reveal = { "close" },
	},
	sort_by = "id",
}

local highlights = {
	background = {
		itatlic = true,
	},
	buffer_selected = {
		bold = false,
		italic = false,
	},
}

M.configure = function()
	-- can't be set in settings.lua because default tabline would flash before bufferline is loaded
	vim.opt.showtabline = 2
	vim.opt.termguicolors = true

	vim.api.nvim_set_keymap(
		"n",
		"<C-1>",
		"<cmd>lua require('bufferline').go_to(1, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-2>",
		"<cmd>lua require('bufferline').go_to(2, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-3>",
		"<cmd>lua require('bufferline').go_to(3, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-4>",
		"<cmd>lua require('bufferline').go_to(4, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-5>",
		"<cmd>lua require('bufferline').go_to(5, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-6>",
		"<cmd>lua require('bufferline').go_to(6, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-7>",
		"<cmd>lua require('bufferline').go_to(7, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-8>",
		"<cmd>lua require('bufferline').go_to(8, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-9>",
		"<cmd>lua require('bufferline').go_to(9, true)<CR>",
		{ noremap = true, silent = true }
	)
	vim.api.nvim_set_keymap(
		"n",
		"<C-0>",
		"<cmd>lua require('bufferline').go_to(0, true)<CR>",
		{ noremap = true, silent = true }
	)

	require("bufferline").setup({
		options = options,
		highlights = highlights,
	})
end

return M
