vim.api.nvim_command "hi clear"

if vim.fn.exists "syntax_on" then
	vim.api.nvim_command "syntax reset"
end

local utils = require("core.theme.utils")
local lsp = require("core.theme.lsp")

local skeletons = {
	lsp,
}

for _, skeleton in ipairs(skeletons) do
	utils.initialize(skeleton)
end
