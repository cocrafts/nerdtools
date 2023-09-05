local M = {}

M.configure = function()
	require("go").setup({
		lsp_gofumpt = true,
		lsp_keymaps = false,
		lsp_inlay_hints = {
			enabled = true,
		},
	})
end

return M
