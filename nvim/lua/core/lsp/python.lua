local M = {}

M.configure = function(lspconfig)
	lspconfig.pyright.setup({
		formatter = "auto",
	})
end

return M
