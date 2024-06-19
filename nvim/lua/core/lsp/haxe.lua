local M = {}

M.configure = function(lspconfig)
	lspconfig.haxe_language_server.setup({
		cmd = { "node", vim.fn.expand("~/Sources/haxe/language-server/bin/server.js") },
	})
end

return M
