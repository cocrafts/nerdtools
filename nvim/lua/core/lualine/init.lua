local M = {}

local options = {
	active = true,
	style = "tokyonight-night",
	tabline = nil,
	extensions = nil,
	on_config_done = nil,
	options = {
		icons_enabled = nil,
		component_separators = nil,
		section_separators = nil,
		theme = nil,
		disabled_filetypes = { statusline = { "alpha" } },
		globalstatus = true,
	},
	sections = {
		lualine_a = nil,
		lualine_b = nil,
		lualine_c = nil,
		lualine_x = nil,
		lualine_y = nil,
		lualine_z = nil,
	},
	inactive_sections = {
		lualine_a = nil,
		lualine_b = nil,
		lualine_c = nil,
		lualine_x = nil,
		lualine_y = nil,
		lualine_z = nil,
	},
}

M.configure = function()
	require("lualine").setup(options)
end

return M
