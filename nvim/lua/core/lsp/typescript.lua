local M = {}

M.configure = function(hints)
	local typescript = require("typescript")

	typescript.setup {
		server = {
			on_attach = function(client, bufnr)
				hints.on_attach(client, bufnr)

				vim.keymap.set("n", "<leader>vi", "<cmd>TypescriptAddMissingImports<CR>", { buffer = bufnr })
			end,
		},
	}
end

return M
