local M = {}
local colors = require("themes.color")
local icons = require("utils.icons")

M.configure = function()
	require("package-info").setup({
		-- Package info now uses highlights instead of colors option
		-- Define custom highlights in your theme if needed
		icons = {
			enable = true,
			style = {
				up_to_date = " " .. icons.ui.Target .. " ",
				outdated = " " .. icons.ui.Target .. " ",
			},
		},
		hide_up_to_date = true,
	})

	-- Set custom highlights instead of colors
	vim.api.nvim_set_hl(0, "PackageInfoUpToDateVersion", { fg = colors.blue })
	vim.api.nvim_set_hl(0, "PackageInfoOutdatedVersion", { fg = colors.gray })
end

return M
