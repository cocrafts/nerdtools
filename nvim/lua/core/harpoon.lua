local M = {}

M.configure = function()
	require("harpoon").setup({
		menu = {
			width = 76,
		},
	})
end

return M
