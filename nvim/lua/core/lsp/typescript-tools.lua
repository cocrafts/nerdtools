local M = {}

M.configure = function()
	require("typescript-tools").setup({
		settings = {
			separate_diagnostic_server = false,
			publish_diagnostic_on = "insert_leave",
			tsserver_plugins = {},
			-- Completely disable all inlay hints to prevent crashes
			tsserver_file_preferences = {
				includeInlayParameterNameHints = "none",
				includeInlayParameterNameHintsWhenArgumentMatchesName = false,
				includeInlayFunctionParameterTypeHints = false,
				includeInlayVariableTypeHints = false,
				includeInlayVariableTypeHintsWhenTypeMatchesName = false,
				includeInlayPropertyDeclarationTypeHints = false,
				includeInlayFunctionLikeReturnTypeHints = false,
				includeInlayEnumMemberValueHints = false,
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
			},
			tsserver_format_options = {
				allowIncompleteCompletions = false,
				allowRenameOfImportPath = false,
				convertTabsToSpaces = true,
			},
			tsserver_max_memory = 3072,
		},
		on_attach = function(client, bufnr)
			-- Disable formatting to prevent conflicts with prettier/eslint
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
			-- Disable inlay hints to prevent crashes
			client.server_capabilities.inlayHintProvider = false
		end,
	})
end

return M
