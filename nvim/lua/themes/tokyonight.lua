local M = {}
local base_colors = require("themes.color")
local helper = require("utils.helper")

local colors = helper.mergeTables(base_colors, {
	functions = "#E95678",
})

if vim.g.neovide then
	colors["gray"] = "#27283a"
end

M.colors = colors
M.options = {
	name = "tokyonight",
	variant = "tokyonight-night",
	setup = {
		style = "night",
		styles = {
			comments = { italic = true },
			keywords = { italic = true },
			floats = "dark",
		},
		hide_inactive_statusline = true,
	},
	highlight = {
		syntax = {
			Keyword = { fg = colors.keywords },
			Comment = { fg = colors.comments, style = "italic" },
			Number = { fg = colors.numbers },
			Function = { fg = colors.functions },
			Identifier = { fg = colors.variables },
			Statement = { fg = colors.keywords },
			String = { fg = colors.strings },
			Type = { fg = colors.types },
			PreProc = { fg = colors.procs },
			Special = { fg = colors.functions },

			luaFunction = { fg = colors.keywords },

			rustMacro = { fg = colors.functions },
			rustStorage = { fg = colors.keywords, style = "italic" },
			rustModPathSep = { fg = colors.fg },
		},
	},
}

M.configure = function()
	require("tokyonight").setup(M.options.setup)
end

return M
