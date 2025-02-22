local M = {}

M.configureBash = function(lspconfig)
	lspconfig.bashls.setup({})
end

M.configureNushell = function(lspconfig)
	lspconfig.nushell.setup({})
end

return M
