local M = {}
local helper = require("utils.helper")
local base_colors = require("themes.colors")

local colors = helper.mergeTables({
	dim = "#2d2d45",
}, base_colors)

M.options = {
	name = "catppuccin",
	variant = "catppuccin-mocha",
	setup = {
		flavour = "mocha",
		background = {
			dark = "mocha",
			light = "latte",
		},
	},
	highlight = {
		gui = {
			NonText = { fg = colors.dim },
			SpecialKey = { fg = colors.dim },
			Whitespace = { fg = colors.dim },
		},
	},
}

M.configure = function()
	require("catppuccin").setup(M.options.setup)
end

return M
