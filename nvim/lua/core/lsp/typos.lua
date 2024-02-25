local M = {}

M.configure = function(lspconfig)
	lspconfig.typos_lsp.setup({
		init_options = {
			config = "~/nerdtools/conf/typos.toml",
			diagnosticSeverity = "Warning"
		},
	})
end

return M
