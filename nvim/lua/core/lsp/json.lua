local M = {}

M.configure = function(lspconfig)
	lspconfig.jsonls.setup({})
	lspconfig.jqls.setup({})
end

return M
