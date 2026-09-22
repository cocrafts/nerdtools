local M = {}

M.configure = function()
	vim.lsp.config("nimls", {})
		vim.lsp.enable("nimls")
end

return M
