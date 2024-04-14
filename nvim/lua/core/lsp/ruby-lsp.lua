local M = {}

M.configure = function(lspconfig)
	lspconfig.ruby_lsp.setup({
		formatter = "auto",
	})
end

return M
