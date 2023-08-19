local M = {}

M.configure = function(lspconfig)
	lspconfig.graphql.setup({
		cmd = { "graphql-lsp", "server", "-m", "stream" },
		filetypes = { "graphql", "typescript", "typescriptreact", "javascript", "javascriptreact" },
	})
end

return M
