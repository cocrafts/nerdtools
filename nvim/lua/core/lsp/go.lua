local M = {}
local config = require("utils.config")
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
		diagnostic = {
			hdlr = true, -- hook lsp diag handler
			signs = false,
			-- set to true: use gopls to format,
			-- false if you want to use other formatter tool(e.g. efm, nulls)
			underline = true,
			virtual_text = { space = 0, prefix = icons.ui.Block }, -- virtual text setup
			update_in_insert = config.use_live_diagnostic,
		},
		lsp_document_formatting = false,
		lsp_inlay_hints = {
			enabled = true,
		},
		gocoverage_sign = icons.ui.Block,
		sign_priority = 5, -- change to a higher number to override other signs
		trouble = false, -- true: use trouble to open quickfix
		luasnip = true,
	})
end

return M
