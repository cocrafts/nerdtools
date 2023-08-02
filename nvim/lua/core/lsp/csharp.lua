local M = {}

M.configure = function(lspconfig)
	lspconfig.omnisharp.setup({
		cmd = { "/Users/le/Sources/omnisharp/run", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
		handlers = {
			["textDocument/definition"] = require("omnisharp_extended").handler,
		},
		enable_editorconfig_support = true,
		enable_roslyn_analyzers = true,
	})
end

return M
