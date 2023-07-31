local M = {}

M.configure = function(lspconfig)
	require("go").setup({
		lsp_cfg = false,
		lsp_gofumpt = true,
		lsp_keymaps = false,
		lsp_inlay_hints = {
			enabled = false,
		},
	})

	local config = require("go.lsp").config()
	lspconfig.gopls.setup(config)
end

return M
