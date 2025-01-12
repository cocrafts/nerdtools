local M = {}

M.configure = function(lspconfig)
	lspconfig.nim_langserver.setup({
		settings = {
			nim = {
				nimsuggestPath = "~/.nimble/bin/nimlangserver",
			},
		},
	})
end

return M
