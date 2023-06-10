local snip = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

local s = snip.s
local i = snip.i
local t = snip.t
local d = snip.dynamic_node
local c = snip.choice_node
local f = snip.function_node
local sn = snip.snip_node

local snippets, autosnippet = {}, {}

local group = vim.api.nvim_create_augroup("Lua Snippets", { clear = true })
local file_pattern = "*.lua"

local printSnippet = s("cl", {
	t('print("'),
	i(1, ""),
	t('")')
})

local snipTemplateSnippet = s("snip", fmt([=[
	local {} = s("{}", fmt([[
		 
	]], {{}}))
]=], {
	i(1, "snippetName"),
	i(2, "shortcut"),
}))

table.insert(snippets, printSnippet)
table.insert(snippets, snipTemplateSnippet)

print("")

return snippets, autosnippet
