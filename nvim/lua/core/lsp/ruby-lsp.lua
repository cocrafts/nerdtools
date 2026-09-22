local M = {}

M.configure = function()
	vim.lsp.config("ruby_lsp", {
	})
		vim.lsp.enable("ruby_lsp")
end

return M
