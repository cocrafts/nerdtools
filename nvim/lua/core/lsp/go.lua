local M = {}

M.configure = function(lspconfig)
	lspconfig.gopls.setup {
		filetypes = { "go", "gomod", "gowork", "gotmpl" },
	}
end

return M
