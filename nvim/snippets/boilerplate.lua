local snip = require("luasnip")
local fmt = require("luasnip.extras.fmt")
local rep = require("luasnip.extras").rep

local s = snip.s
local i = snip.i
local t = snip.t
local d = snip.dynamic_node
local c = snip.choice_node
local f = snip.function_node
local sn = snip.snip_node

local snippets, autosnippet = {}, {}

local group = vim.api.nvim_create_augroup("Typescript Snippets", { clear = true })
local file_pattern = "*.lua"

return snippets, autosnippet
