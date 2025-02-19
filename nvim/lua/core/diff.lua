local M = {}
local icons = require("utils.icons")

M.configureDiffview = function()
	require("diffview").setup({
		enhanced_diff_hl = true,
		use_icons = true,
		icons = { -- Only applies when use_icons is true.
			folder_closed = icons.ui.Folder,
			folder_open = icons.ui.FolderOpen,
		},
		signs = {
			fold_closed = "",
			fold_open = "",
			done = icons.ui.Check,
		},
	})
end

M.configureBlame = function()
	require("blame").setup({})
end

return M
