local M = {}

M.configure = function()
	require("supermaven-nvim").setup({
		disable_keymaps = true,
		condition = function()
			local filename = vim.fn.expand("%:t")
			return string.match(filename, "credentials") or string.match(filename, "^%.env%..*")
		end,
	})
end

return M
