local M = {}
local icons = require("utils.icons")

local options = {
	enabled = true,
	buftype_exclude = { "terminal", "nofile" },
	filetype_exclude = {
		"help",
		"startify",
		"dashboard",
		"lazy",
		"NvimTree",
		"Trouble",
		"text",
	},
	char_highlight_list = {
		"IndentBlanklineIndent",
	},
	show_end_of_line = false,
	show_current_context = true,
	show_current_context_start = true,
	char = icons.ui.LineLeft,
	context_char = icons.ui.LineLeft,
	show_trailing_blankline_indent = false,
	show_first_indent_level = true,
	use_treesitter = true,
}

M.configure = function()
	require("indent_blankline").setup(options)
end

return M
