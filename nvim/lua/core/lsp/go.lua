local M = {}
local icons = require("utils.icons")

M.configure = function()
	require("go").setup({
		goimport = "goimports_reviser",
		fillstruct = "gopls",
		gofmt = "gofumpt",
		lsp_cfg = true,
		lsp_gofumpt = true,
		lsp_keymaps = false,
		lsp_codelens = true,
		lsp_diag_hdlr = true, -- hook lsp diag handler
		lsp_diag_virtual_text = { space = 0, prefix = icons.ui.Block }, -- virtual text setup
		lsp_diag_signs = true,
		lsp_diag_update_in_insert = true,
		lsp_document_formatting = false,
		-- set to true: use gopls to format,
		-- false if you want to use other formatter tool(e.g. efm, nulls)
		lsp_diag_underline = true,
		lsp_inlay_hints = {
			enabled = true,
		},
		gocoverage_sign = icons.ui.Block,
		sign_priority = 5, -- change to a higher number to override other signs
		trouble = true, -- true: use trouble to open quickfix
		luasnip = true,
	})
end

return M
