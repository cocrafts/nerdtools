local M = {}

M.configure = function()
	vim.lsp.config("gdscript", {})
		vim.lsp.enable("gdscript")
end

return M
