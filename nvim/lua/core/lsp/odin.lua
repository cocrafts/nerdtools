local M = {}

M.configure = function()
	vim.lsp.config("ols", {})
		vim.lsp.enable("ols")
end

return M
