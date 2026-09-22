local M = {}

M.configure = function()
	vim.lsp.config("eslint", {
		on_attach = function(_, bufnr)
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = bufnr,
				command = "EslintFixAll",
			})
		end,
	})
		vim.lsp.enable("eslint")
end

return M
