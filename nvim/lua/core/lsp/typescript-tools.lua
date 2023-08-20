local config = require("utils.config")
local M = {}

M.configure = function(lspconfig)
	local options = {
		settings = {
			typescript = {},
			javascript = {},
		},
	}

	if config.use_inlay_hints then
		local hint_options = {
			includeInlayParameterNameHints = "all",
			includeInlayParameterNameHintsWhenArgumentMatchesName = false,
			includeInlayFunctionParameterTypeHints = true,
			includeInlayVariableTypeHints = true,
			includeInlayVariableTypeHintsWhenTypeMatchesName = false,
			includeInlayPropertyDeclarationTypeHints = true,
			includeInlayFunctionLikeReturnTypeHints = true,
			includeInlayEnumMemberValueHints = true,
		}

		options.settings.typescript["inlayHints"] = hint_options
		options.settings.javascript["inlayHints"] = hint_options
	end

	lspconfig.tsserver.setup(options)

	require("typescript-tools").setup({
		settings = {
			separate_diagnostic_server = true,
			publish_diagnostic_on = "change",
		},
	})
end

return M
