local M = {}
local icons = require("utils.icons")
local colors = require("themes.colors")

M.configure = function()
	require("package-info").setup {
		colors = {
			up_to_date = colors.blue,
			outdated = colors.gray,
		},
		icons = {
			enable = true,
			style = {
				up_to_date = " " .. icons.git.FileStaged .. " ",
				outdated = " " .. icons.git.FileUnstaged .. " ",
			},
		},
	}
end

return M
