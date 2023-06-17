local M = {}
local icons = require("utils.icons")
local components = require("core.lualine.components")

local options = {
	active = true,
	style = "tokyonight-night",
	tabline = nil,
	extensions = nil,
	on_config_done = nil,
	options = {
		theme = "auto",
		globalstatus = true,
		icons_enabled = true,
		component_separators = { left = "", right = "" },
		-- section_separators = { left = "", right = "" },
		section_separators = { left = "", right = "" },
		-- section_separators = { left = "", right = "" },
		disabled_filetypes = { "alpha" },
	},
	sections = {
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
}

M.configure = function()
	require("lualine").setup(options)
end

return M
