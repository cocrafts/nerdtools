local icons = require("utils.icons")

return {
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
