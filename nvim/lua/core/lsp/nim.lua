local M = {}

M.configure = function(lspconfig)
	lspconfig.nim_langserver.setup({
		settings = {
			nim = {
				nimsuggestPath = "~/.nimble/bin/nimsuggest",
			},
		},
	})
end

return M
