local M = {}

M.configure = function(lspconfig)
	lspconfig.sqls.setup({
		on_attach = function(client, bufnr)
			require("sqls").on_attach(client, bufnr)
		end,
	})
end

return M
