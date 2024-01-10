local M = {}

M.configure = function(lspconfig)
	lspconfig.terraformls.setup({})
end

return M
