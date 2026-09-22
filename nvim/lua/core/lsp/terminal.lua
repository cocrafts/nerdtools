local M = {}

M.configureBash = function()
	vim.lsp.config("bashls", {})
		vim.lsp.enable("bashls")
end

M.configureNushell = function()
	vim.lsp.config("nushell", {})
		vim.lsp.enable("nushell")
end

return M
