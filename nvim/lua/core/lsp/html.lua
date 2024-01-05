local M = {}

M.configure = function(lspconfig)
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	lspconfig.html.setup({
		capabilities = capabilities,
	})

	lspconfig.cssls.setup({
		capabilities = capabilities,
	})
end

return M
