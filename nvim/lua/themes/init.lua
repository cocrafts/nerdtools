local utils = require("themes.utils")
local colors = require("themes.colors")
local theme = require("utils.config").theme

theme.configure()
vim.cmd("colorscheme " .. theme.options.variant)

theme.options.highlight.system = {
	PanelHeading = { bg = colors.buffer_bg },

	NeoTreeNormal = { bg = colors.explorer_bg },
	NeoTreeNormalNC = { bg = colors.explorer_bg },
	NeoTreeWinSeparator = { fg = colors.explorer_bg, bg = colors.explorer_bg },
}

for _, group in pairs(theme.options.highlight) do
	utils.initialize(group)
end

-- vim.api.nvim_command "hi clear"

-- if vim.fn.exists "syntax_on" then
-- 	vim.api.nvim_command "syntax reset"
-- end
