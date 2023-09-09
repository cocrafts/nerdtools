local M = {}

M.configure = function()
	require("satellite").setup({
		excluded_filetypes = {},
		current_only = true,
		winblend = 36,
		zindex = 40,
		width = 2,
		handlers = {
			search = {
				enable = true,
			},
			diagnostic = {
				enable = true,
				signs = { "-", "=", "≡" },
				min_severity = vim.diagnostic.severity.HINT,
			},
			gitsigns = {
				enable = true,
				signs = { -- can only be a single character (multi-byte is okay)
					add = "│",
					change = "│",
					delete = "-",
				},
			},
			marks = {
				enable = true,
				show_builtins = false, -- shows the builtin marks like [ ] < >
			},
		},
	})
end

return M
