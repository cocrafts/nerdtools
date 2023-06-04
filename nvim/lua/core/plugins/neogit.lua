local M = {}
local icons = require("utils.icons")

local options = {
	signs = {
		section = {
			icons.ui.TriangleShortArrowRight,
			icons.ui.TriangleShortArrowDown,
		},
		item = {
			icons.ui.TriangleShortArrowRight,
			icons.ui.TriangleShortArrowDown,
		},
		hunk = { "", "" },
  },
	integrations = {
		diffview = true,
	},
}

M.configure = function()
	require("neogit").setup(options)
end

return M
