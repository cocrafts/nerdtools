local M = {}

M.configure = function()
	require("typescript-tools").setup({
		settings = {
			separate_diagnostic_server = true,
			publish_diagnostic_on = "change",
			tsserver_file_preferences = {
				includeInlayParameterNameHints = "all",
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = true,
			},
			tsserver_format_options = {
				allowIncompleteCompletions = false,
				allowRenameOfImportPath = false,
			},
		},
	})
end

return M
