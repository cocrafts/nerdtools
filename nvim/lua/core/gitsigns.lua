local M = {}
local icons = require("utils.icons")

M.configure = function()
	require("gitsigns").setup({
		signs = {
			add = {
				hl = "GitSignsAdd",
				text = icons.ui.BoldLineLeft,
				numhl = "GitSignsAddNr",
				linehl = "GitSignsAddLn",
			},
			change = {
				hl = "GitSignsChange",
				text = icons.ui.BoldLineLeft,
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
			delete = {
				hl = "GitSignsDelete",
				text = icons.ui.Triangle,
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			topdelete = {
				hl = "GitSignsDelete",
				text = icons.ui.Triangle,
				numhl = "GitSignsDeleteNr",
				linehl = "GitSignsDeleteLn",
			},
			changedelete = {
				hl = "GitSignsChange",
				text = icons.ui.BoldLineLeft,
				numhl = "GitSignsChangeNr",
				linehl = "GitSignsChangeLn",
			},
			untracked = {
				hl = "GitSignsChange",
				text = icons.ui.BoldLineLeft,
				numhl = "GitSignsUntrackedNr",
				linehl = "GitSignsUntrackedLn",
			},
		},
		signcolumn = true,
		numhl = false,
		linehl = false,
		word_diff = false,
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		attach_to_untracked = true,
		current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 0,
			ignore_whitespace = false,
		},
		current_line_blame_formatter = " <author>, <author_time:%R> • <summary> ",
		sign_priority = 6,
		status_formatter = nil, -- Use default
		update_debounce = 200,
		max_file_length = 40000,
		preview_config = {
			border = "rounded",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		yadm = { enable = false },
	})
end

return M
