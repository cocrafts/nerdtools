local M = {}

M.configure = function()
	require("guess-indent").setup({
		auto_cmd = false,
	})
end

return M
