local M = {}

M.configure = function(lspconfig)
	lspconfig.omnisharp.setup({
		cmd = { "dotnet", "/Users/le/Sources/omnisharp-osx-arm64-net6.0/OmniSharp.dll" },
		enable_editorconfig_support = false,
		enable_roslyn_analyzers = true,
		organize_imports_on_format = true,
		enable_import_completion = false,
		sdk_include_prereleases = true,
		analyze_open_documents_only = false,
	})
end

return M
