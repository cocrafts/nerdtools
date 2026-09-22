local M = {}

M.configure = function()
	vim.lsp.config("gleam", {})
		vim.lsp.enable("gleam")
end

return M
