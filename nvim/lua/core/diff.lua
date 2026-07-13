local M = {}
local icons = require("utils.icons")

-- Set diff filler characters globally to use diagonal lines
vim.opt.fillchars:append("diff:╱")

M.configureDiffview = function()
	local actions = require("diffview.actions")
	local toggle_files = { "n", "<leader>e", actions.toggle_files, { desc = "Toggle the file panel" } }
	local unmap_b = { "n", "<leader>b", false }

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
		keymaps = {
			view = { unmap_b, toggle_files },
			file_panel = { unmap_b, toggle_files },
			file_history_panel = { unmap_b, toggle_files },
		},
		hooks = {
			view_opened = function(view)
				view.panel:close()
			end,
		},
	})
end

M.configureBlame = function()
	require("blame").setup({})
end

return M
