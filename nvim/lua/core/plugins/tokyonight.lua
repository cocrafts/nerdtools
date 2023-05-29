local M = {}

local options = {
	style = "night",
	styles = {
		comments = { italic = true },
		keywords = { italic = true },
		floats = "dark"
	},
	hide_inactive_statusline = true,
}

M.configure = function()
	vim.cmd [[colorscheme tokyonight-night]]
	require("tokyonight").setup(options)
end

return M
