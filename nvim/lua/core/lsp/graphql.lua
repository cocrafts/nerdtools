local M = {}

M.configure = function()
	vim.lsp.config("graphql", {
		cmd = { "graphql-lsp", "server", "-m", "stream" },
		filetypes = { "graphql", "typescript", "typescriptreact", "javascript", "javascriptreact" },
	})
		vim.lsp.enable("graphql")
end

return M
