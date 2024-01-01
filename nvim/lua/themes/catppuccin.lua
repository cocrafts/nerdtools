local M = {}
local base_colors = require("themes.color")
local helper = require("utils.helper")

local colors = helper.mergeTables(base_colors, {
	bg = "#1e1e2e",
	buffer_bg = "#181826",
	explorer_bg = "#181826",
	float_border = "#51afef",

	dim = "#2d2d45",
	cursor = "#2a2b3c",
})

M.colors = colors
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
		syntax = {},
	},
}

M.configure = function()
	require("catppuccin").setup(M.options.setup)
end

return M
