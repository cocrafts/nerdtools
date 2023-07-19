local M = {}

M.configure = function()
	require("mason").setup()
	require("mason-lspconfig").setup({
		ensure_installed = {
			"gopls",
			"eslint",
			"graphql",
			"tsserver",
			"jsonls",
			"html",
			"cssls",
			"lua_ls",
			"ruby_ls",
			"rust_analyzer",
		},
	})
end

return M
