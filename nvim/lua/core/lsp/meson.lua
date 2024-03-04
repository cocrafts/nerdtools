local M = {}

M.configure = function(lspconfig)
	lspconfig.swift_mesonls.setup({})
end

return M
