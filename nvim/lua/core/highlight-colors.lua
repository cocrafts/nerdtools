local M = {}

M.configure = function()
	require("nvim-highlight-colors").setup({
		render = "virtual",
	})
end

return M
