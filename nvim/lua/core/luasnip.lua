local M = {}
local theme = require("utils.config").theme

M.configure = function()
	local snip = require("luasnip")
	local types = require("luasnip.util.types")

	require("luasnip.loaders.from_lua").lazy_load({
		paths = "./lua/snippets",
	})

	-- NOTE: Not using filetype_extend because it causes snippet reuse
	-- Instead, typescript.lua/typescriptreact.lua/javascriptreact.lua
	-- use dofile() to load fresh instances of JavaScript snippets

	snip.config.set_config({
		history = true,
		updateevents = "TextChanged,TextChangedI",
		enable_autosnippets = true,
		ext_opts = {
			[types.choiceNode] = {
				active = {
					virt_text = { { "*", theme.options.variant } },
				},
			},
		},
	})
end

return M
