local M = {}

M.configure = function()
	if vim.loop.os_uname().sysname == "Darwin" then
		require("mason").setup()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"gopls",
				"graphql",
				"efm",
				-- "omnisharp",
				"stylelint_lsp",
				"jsonls",
				"html",
				"cssls",
				"lua_ls",
				"ruby_ls",
				"pyright",
				"rust_analyzer",
				"zls",
			},
		})
	end
end

return M
