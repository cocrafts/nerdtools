local M = {}

M.configure = function()
	vim.lsp.config("zls", {})
		vim.lsp.enable("zls")
end

return M
