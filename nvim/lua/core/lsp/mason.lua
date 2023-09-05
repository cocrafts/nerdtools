local M = {}

M.configure = function()
	require("mason").setup()
	require("mason-lspconfig").setup({
		ensure_installed = {
			"gopls",
			"graphql",
			"omnisharp",
			"stylelint_lsp",
			"jsonls",
			"html",
			"cssls",
			"lua_ls",
			"ruby_ls",
			"rust_analyzer",
			"zls",
		},
	})
end

return M
