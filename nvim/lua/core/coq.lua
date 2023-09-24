local config = require("utils.config")
local icons = require("utils.icons")
local M = {}

M.settings = {
	auto_start = "shut-up",
	keymap = {
		pre_select = true,
		bigger_preview = "",
		jump_to_mark = "",
	},
	display = {
		ghost_text = {
			context = { string.format(" %s ", icons.ui.PointArrow), "" },
		},
		pum = {
			kind_context = { "", "" },
			source_context = { "", "" },
		},
		icons = {
			mode = "short",
			mappings = icons.kind,
		},
		preview = {
			positions = {
				north = 1,
				south = 2,
				west = 3,
				east = 4,
			},
		},
	},
}

M.lsp_ensure_capabilities = function(options)
	if config.use_cmp then
		return options
	end

	return require("coq").lsp_ensure_capabilities(options)
end

return M
