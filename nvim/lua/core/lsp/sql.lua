local M = {}

M.configure = function()
	vim.lsp.config("sqls", {
		on_attach = function(client, bufnr)
			require("sqls").on_attach(client, bufnr)
		end,
	})
		vim.lsp.enable("sqls")
end

return M
