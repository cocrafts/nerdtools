local coq = require("coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.graphql.setup(coq.lsp_ensure_capabilities({
		cmd = { "graphql-lsp", "server", "-m", "stream" },
		filetypes = { "graphql", "typescript", "typescriptreact", "javascript", "javascriptreact" },
	}))
end

return M
