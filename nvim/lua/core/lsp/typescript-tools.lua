local M = {}

M.configure = function()
	require("typescript-tools").setup({
		settings = {
			separate_diagnostic_server = false,
			publish_diagnostic_on = "insert_leave",
			tsserver_plugins = {
				"@styled/typescript-styled-plugin",
			},
			-- Reduce memory usage by limiting inlay hints
			tsserver_file_preferences = {
				includeInlayParameterNameHints = "literals",               -- Changed from "all"
				includeInlayParameterNameHintsWhenArgumentMatchesName = false, -- Changed from true
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = false,
				includeInlayVariableTypeHintsWhenTypeMatchesName = false, -- Changed from true
				includeInlayPropertyDeclarationTypeHints = false,     -- Changed from true
				includeInlayFunctionLikeReturnTypeHints = false,
				includeInlayEnumMemberValueHints = false,             -- Changed from true
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
			},
			tsserver_format_options = {
				allowIncompleteCompletions = false,
				allowRenameOfImportPath = false,
				convertTabsToSpaces = true,
			},
			-- Add memory limit to prevent excessive memory usage
			tsserver_max_memory = 3072, -- Limit to 3GB max
		},
		-- Add timeout to prevent hanging processes
		on_attach = function(client, bufnr)
			-- Disable formatting to prevent conflicts with prettier/eslint
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
		end,
	})
end

return M
