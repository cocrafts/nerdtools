local M = {}

M.configure = function(lspconfig)
	lspconfig.graphql.setup({
		cmd = { "graphql-lsp", "server", "-m", "stream" },
		filetypes = { "graphql", "typescriptreact", "javascriptreact" },
	})
end

return M
