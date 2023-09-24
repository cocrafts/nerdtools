local coq = require("coq")
local M = {}

M.configure = function(lspconfig)
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	lspconfig.html.setup(coq.lsp_ensure_capabilities({
		capabilities = capabilities,
	}))

	lspconfig.cssls.setup(coq.lsp_ensure_capabilities({
		capabilities = capabilities,
	}))
end

return M
