local coq = require("coq")
local M = {}

M.configure = function()
	require("typescript-tools").setup(coq.lsp_ensure_capabilities({
		settings = {
			separate_diagnostic_server = true,
			publish_diagnostic_on = "change",
			tsserver_file_preferences = {
				includeInlayParameterNameHints = "all",
				includeCompletionsForModuleExports = true,
				quotePreference = "auto",
			},
			tsserver_format_options = {
				allowIncompleteCompletions = false,
				allowRenameOfImportPath = false,
				convertTabsToSpaces = false,
			},
		},
	}))
end

return M
