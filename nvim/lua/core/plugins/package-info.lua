local M = {}
local icons = require("utils.icons")
local colors = require("themes.color")

M.configure = function()
	require("package-info").setup({
		colors = {
			up_to_date = colors.blue,
			outdated = colors.gray,
		},
		icons = {
			enable = true,
			style = {
				up_to_date = " " .. icons.ui.Target .. " ",
				outdated = " " .. icons.ui.Target .. " ",
			},
		},
	})
end

return M
