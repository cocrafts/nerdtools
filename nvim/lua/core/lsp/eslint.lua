local M = {}

M.configure = function(lspconfig)
	lspconfig.eslint.setup {
		on_attach = function(_, bufnr)
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = bufnr,
				command = "silent! EslintFixAll",
			})
		end,
	}
end

return M
