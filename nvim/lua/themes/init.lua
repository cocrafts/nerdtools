local utils = require("themes.utils")
local colors = require("themes.color")
local theme = require("utils.config").theme

theme.configure()
vim.cmd("colorscheme " .. theme.options.variant)

theme.options.highlight.system = {
	PanelHeading = { bg = colors.buffer_bg },

	NeoTreeNormal = { bg = colors.explorer_bg },
	NeoTreeNormalNC = { bg = colors.explorer_bg },
	NeoTreeEndOfBuffer = { fg = colors.explorer_bg },
	NeoTreeWinSeparator = { fg = colors.explorer_bg, bg = colors.explorer_bg },
	NeoTreeDirectoryName = { fg = colors.white },
	-- git file name
	NeoTreeGitAdded = { fg = colors.types, style = "bold" },
	NeoTreeGitConflict = { fg = colors.red, style = "bold" },
	NeoTreeGitDeleted = { fg = colors.comments, style = "bold" },
	NeoTreeGitIgnored = { fg = colors.gray, style = "bold" },
	NeoTreeGitModified = { fg = colors.blue, style = "bold" },
	NeoTreeGitUntracked = { fg = colors.green, style = "bold" },
	-- git symbol
	NeoTreeGitStaged = { fg = colors.gray, style = "bold" },
	NeoTreeGitUnstaged = { fg = colors.green, style = "bold" },

	-- Telescope
	TelescopeNormal = { bg = colors.bg },
	TelescopeBorder = { bg = colors.bg, fg = colors.green },

	-- Gitsign
	GitSignsChange = { fg = colors.green },
}

for _, group in pairs(theme.options.highlight) do
	utils.initialize(group)
end

-- vim.api.nvim_command "hi clear"

-- if vim.fn.exists "syntax_on" then
-- 	vim.api.nvim_command "syntax reset"
-- end
