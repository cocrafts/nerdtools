local M = {}

M.configure = function()
	require("illuminate").configure({
		providers = {
			"lsp",
			"treesitter",
			"regex",
		},
		delay = 100,
		under_cursor = true,
		should_enable = function(bufnr)
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { line - 1, 0 } })
			while node do
				local node_type = node:type()
				if node_type:match("comment") then
					return false
				end
				node = node:parent()
			end
			return true
		end,
	})
end

return M
