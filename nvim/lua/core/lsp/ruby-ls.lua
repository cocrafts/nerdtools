local M = {}

M.configure = function(lspconfig)
	lspconfig.ruby_ls.setup({
		formatter = "auto",
	})
end

return M
