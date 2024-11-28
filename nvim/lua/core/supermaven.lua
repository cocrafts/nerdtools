local M = {}

M.configure = function()
	require("supermaven-nvim").setup({
		disable_keymaps = true,
	})
end

return M
