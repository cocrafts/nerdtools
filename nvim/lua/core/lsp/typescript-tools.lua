local M = {}

M.configure = function()
	require("typescript-tools").setup({
		settings = {
			separate_diagnostic_server = true,
			publish_diagnostic_on = "change",
			tsserver_plugins = {
				"@styled/typescript-styled-plugin",
			},
			tsserver_file_preferences = {
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = false,
				includeInlayVariableTypeHintsWhenTypeMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = false,
				includeInlayEnumMemberValueHints = true,
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
			},
			tsserver_format_options = {
				allowIncompleteCompletions = false,
				allowRenameOfImportPath = false,
				convertTabsToSpaces = true,
			},
		},
	})
end

return M
