local M = {}
local settings = require("utils.settings")

M.configure = function()
	local snip = require("luasnip")
	local types = require("luasnip.util.types")

	require("luasnip.loaders.from_lua").lazy_load({ paths = "./lua/snippets" })

	snip.config.set_config({
		history = true,
		updateevents = "TextChanged,TextChangedI",
		enable_autosnippets = true,
		ext_opts = {
			[types.choiceNode] = {
				active = {
					virt_text = { { "*", settings.theme.variant } },
				},
			},
		},
	})
end

return M
