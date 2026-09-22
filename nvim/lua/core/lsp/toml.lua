local M = {}

M.configure = function()
	vim.lsp.config("taplo", {})
		vim.lsp.enable("taplo")
end

return M
