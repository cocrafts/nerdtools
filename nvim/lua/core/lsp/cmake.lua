local M = {}

M.configure = function()
	vim.lsp.config("neocmake", {})
		vim.lsp.enable("neocmake")
end

return M
