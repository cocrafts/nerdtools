local M = {}

M.configure = function(lspconfig)
	lspconfig.sourcekit.setup({
		capabilities = {
			workspace = {
				didChangeWatchedFiles = {
					dynamicRegistration = true,
				},
			},
		},
		root_dir = require("lspconfig.util").root_pattern(
			"buildServer.json",
			"*.xcodeproj",
			"*.xcworkspace",
			"compile_commands.json",
			"Package.swift",
			"Project.swift",
			".git"
		),
	})
end

return M
