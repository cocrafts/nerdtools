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
			cursor = {
				enable = false,
				overlap = false,
				priority = 0,
			},
			diagnostic = {
				enable = false,
				signs = { "-", "=", "≡" },
				min_severity = vim.diagnostic.severity.ERROR,
			},
			gitsigns = {
				enable = false,
				signs = { -- can only be a single character (multi-byte is okay)
					add = "│",
					change = "│",
					delete = "-",
				},
			},
			marks = {
				enable = false,
				show_builtins = false, -- shows the builtin marks like [ ] < >
				overlap = false,
				priority = 1,
			},
			quickfix = {
				enable = false,
				overlap = false,
				priority = 0,
			},
		},
	})
end

return M
