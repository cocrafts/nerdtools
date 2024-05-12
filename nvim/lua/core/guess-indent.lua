local M = {}

M.configure = function()
	require("guess-indent").setup({
		auto_cmd = true,
	})
end

return M
