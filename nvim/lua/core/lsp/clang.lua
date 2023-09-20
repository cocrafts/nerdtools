local M = {}

M.configure = function(lspconfig)
	lspconfig.clangd.setup({})
end

return M
