local M = {}

M.configure = function()
	vim.lsp.config("swift_mesonls", {})
		vim.lsp.enable("swift_mesonls")
end

return M
