local M = {}

M.configure = function()
	vim.lsp.config("jsonls", {})
		vim.lsp.enable("jsonls")
	vim.lsp.config("jqls", {})
		vim.lsp.enable("jqls")
end

return M
