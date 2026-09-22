local M = {}

M.configure = function()
	vim.lsp.config("terraformls", {})
		vim.lsp.enable("terraformls")
end

return M
