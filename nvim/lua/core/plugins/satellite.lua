local M = {}

local options = {
	winblend = 92,
	zindex = 40,
	width = 2,
	handlers = {
    search = {
      enable = true,
    },
    diagnostic = {
      enable = true,
      signs = {'-', '=', '≡'},
      min_severity = vim.diagnostic.severity.HINT,
    },
    gitsigns = {
      enable = true,
      signs = { -- can only be a single character (multibyte is okay)
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
}

M.configure = function()
	require("satellite").setup(options)
end

return M
