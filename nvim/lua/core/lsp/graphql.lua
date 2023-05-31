local M = {}

local options = {
	cmd = { "graphql-lsp", "server", "-m", "stream" },
	filetypes = { "graphql", "typescriptreact", "javascriptreact" },
}

M.configure = function(lspconfig)
	lspconfig.graphql.setup(options)
end

return M
