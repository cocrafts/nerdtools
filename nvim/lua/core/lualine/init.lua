local M = {}
local theme = require("utils.config").theme
local components = require("core.lualine.components")

M.configure = function()
	require("lualine").setup({
		active = true,
		style = theme.options.variant,
		tabline = nil,
		extensions = nil,
		on_config_done = nil,
		options = {
			theme = "auto",
			globalstatus = true,
			icons_enabled = true,
			component_separators = { left = "", right = "" },
			section_separators = vim.g.neovide and { left = "", right = "" } or { left = "", right = "" },
			-- section_separators = { left = "", right = "" },
			-- section_separators = { left = "", right = "" },
			disabled_filetypes = { "alpha" },
		},
		sections = {
			lualine_a = {
				components.mode,
			},
			lualine_b = {
				components.cwd,
				components.branch,
			},
			lualine_c = {
				components.diff,
			},
			lualine_x = {
				components.diagnostics,
				components.lsp,
				components.spaces,
				components.filetype,
			},
			lualine_y = {
				components.location,
			},
			lualine_z = {
				components.encoding,
			},
		},
		inactive_sections = {
			lualine_a = {
				components.mode,
			},
			lualine_b = {
				components.branch,
			},
			lualine_c = {
				components.diff,
			},
			lualine_x = {
				components.diagnostics,
				components.lsp,
				components.spaces,
				components.filetype,
			},
			lualine_y = {
				components.location,
			},
			lualine_z = {
				components.encoding,
			},
		},
	})
end

return M
