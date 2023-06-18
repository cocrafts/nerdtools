local utils = require("themes.utils")
local theme = require("utils.config").theme

theme.configure()
vim.cmd("colorscheme " .. theme.options.variant)

for _, group in pairs(theme.options.highlight) do
	utils.initialize(group)
end

-- vim.api.nvim_command "hi clear"

-- if vim.fn.exists "syntax_on" then
-- 	vim.api.nvim_command "syntax reset"
-- end
