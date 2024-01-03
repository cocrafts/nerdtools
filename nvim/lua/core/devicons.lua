local M = {}
local theme = require("utils.config").theme
local colors = theme.colors

M.configure = function()
	require("nvim-web-devicons").setup({
		color_icons = true,
		override = {
			toml = {
				icon = "",
				color = colors.orange,
			},
		},
	})
end

return M
