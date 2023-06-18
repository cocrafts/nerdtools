-- vim.api.nvim_command "hi clear"

-- if vim.fn.exists "syntax_on" then
-- 	vim.api.nvim_command "syntax reset"
-- end

local utils = require("themes.utils")
local lsp = require("themes.lsp")
local highlight = require("themes.highlight")

local skeletons = {
	lsp,
	highlight,
}

for _, skeleton in ipairs(skeletons) do
	utils.initialize(skeleton)
end
