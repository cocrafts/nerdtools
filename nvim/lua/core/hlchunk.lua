local M = {}
local theme = require("utils.config").theme
local colors = theme.colors

M.configure = function()
	require("hlchunk").setup({
		chunk = {
			chars = {
				horizontal_line = "─",
				vertical_line = "│",
				left_top = "╭",
				left_bottom = "╰",
				right_arrow = "─",
			},
			style = {
				{ fg = colors.blue },
				{ fg = colors.red }, -- this fg is used to highlight wrong chunk
			},
		},
		line_num = {
			enable = false,
		},
		blank = {
			enable = false,
		},
	})
end

return M
