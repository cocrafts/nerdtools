local M = {}

M.configure = function()
	local elixir = require("elixir")
	local elixirls = require("elixir.elixirls")

	elixir.setup({
		elixirls = {
			enable = true,
			settings = elixirls.settings({
				dialyzerEnabled = true,
				enableTestLenses = true,
				fetchDeps = true,
				suggestSpecs = true,
			}),
			on_attach = function(_client, _bufnr)
				vim.keymap.set("n", "<space>fp", ":ElixirFromPipe<cr>", { buffer = true, noremap = true })
				vim.keymap.set("n", "<space>tp", ":ElixirToPipe<cr>", { buffer = true, noremap = true })
				vim.keymap.set("v", "<space>em", ":ElixirExpandMacro<cr>", { buffer = true, noremap = true })
			end,
		},
		projectionist = { enable = false }, -- Disable to avoid conflicts
	})
end

return M
