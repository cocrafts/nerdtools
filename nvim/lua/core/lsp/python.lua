local M = {}

M.configure = function()
	vim.lsp.config("pyright", {
	})
		vim.lsp.enable("pyright")
end

return M
