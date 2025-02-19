local M = {}
local colors = require("themes.color")
local icons = require("utils.icons")

M.configure = function()
	require("package-info").setup({
		colors = {
			up_to_date = colors.blue,
			outdated = colors.gray,
			invalid = colors.red,
		},
		icons = {
			enable = true,
			style = {
				up_to_date = " " .. icons.ui.Target .. " ",
				outdated = " " .. icons.ui.Target .. " ",
			},
		},
		hide_up_to_date = true,
	})
end

return M
