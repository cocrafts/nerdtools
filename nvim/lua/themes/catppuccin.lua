local M = {}
local colors = {
	dim = "#2d2d45",
}

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
