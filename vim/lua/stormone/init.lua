vim.api.nvim_command "hi clear"
if vim.fn.exists "syntax_on" then
  vim.api.nvim_command "syntax reset"
end

vim.o.background = "dark"
vim.o.termguicolors = true
vim.g.colors_name = "stormone"

local utils = require("stormone.utils")
local highlights = require("stormone.highlights")
local treesitter = require("stormone.treesitter")
local gui = require("stormone.gui")
local lsp = require("stormone.lsp")
local diff = require("stormone.diff")

local skeletons = {
  highlights,
  treesitter,
  gui,
  lsp,
  diff,
}

for _, skeleton in ipairs(skeletons) do
  utils.initialize(skeleton)
end
