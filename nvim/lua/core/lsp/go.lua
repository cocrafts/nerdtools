local config = require("utils.config")
local icons = require("utils.icons")
local M = {}

M.configure = function(lspconfig)
	require("go").setup({
		goimports = "gopls",
		fillstruct = "gopls",
		gofmt = "gofumpt",
		lsp_cfg = false,
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
		lsp_document_formatting = true,
		lsp_inlay_hints = {
			enable = false,
		},
		gocoverage_sign = icons.ui.Block,
		sign_priority = 5, -- change to a higher number to override other signs
		trouble = false, -- true: use trouble to open quickfix
		luasnip = true,
	})

	local lsp_config = require("go.lsp").config()
	lsp_config.settings = vim.tbl_deep_extend("force", lsp_config.settings or {}, {
		gopls = {
			hints = {
				rangeVariableTypes = true,
				parameterNames = false,
				constantValues = true,
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				functionTypeParameters = true,
			},
		},
	})

	lspconfig.gopls.setup(lsp_config)
end

return M
