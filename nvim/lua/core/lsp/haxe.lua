local M = {}

M.configure = function()
	vim.lsp.config("haxe_language_server", {
		cmd = { "node", vim.fn.expand("~/Sources/haxe/language-server/bin/server.js") },
		filetypes = { "haxe" },
	})
		vim.lsp.enable("haxe_language_server")
end

return M
