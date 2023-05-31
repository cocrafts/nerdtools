local M = {}
local config = require("utils.config")
local icons = require("utils.icons")

local options = {
	disable_netrw = false,
	hijack_cursor = false,
	hijack_netrw = true,
	hijack_unnamed_buffer_when_opening = false,
	sort_by = "name",
	root_dirs = {},
	prefer_startup_root = false,
	sync_root_with_cwd = true,
	reload_on_bufenter = false,
	respect_buf_cwd = false,
	on_attach = "default",
	remove_keymaps = false,
	select_prompts = false,
	view = {
		adaptive_size = false,
		centralize_selection = true,
		width = 30,
		hide_root_folder = false,
		side = "left",
		preserve_window_proportions = false,
		number = false,
		relativenumber = false,
		signcolumn = "yes",
		float = {
			enable = false,
			quit_on_focus_loss = true,
			open_win_config = {
				relative = "editor",
				border = "rounded",
				width = 30,
				height = 30,
				row = 1,
				col = 1,
			},
		},
	},
	renderer = {
		add_trailing = false,
		group_empty = false,
		highlight_git = true,
		full_name = false,
		highlight_opened_files = "none",
		root_folder_label = ":t",
		indent_width = 2,
		indent_markers = {
			enable = false,
			inline_arrows = true,
			icons = {
				corner = "└",
				edge = "│",
				item = "│",
				none = " ",
			},
		},
		icons = {
			webdev_colors = config.use_icons,
			git_placement = "after",
			padding = " ",
			symlink_arrow = " ➛ ",
			show = {
				file = config.use_icons,
				folder = config.use_icons,
				folder_arrow = config.use_icons,
				git = config.use_icons,
			},
			glyphs = {
				default = icons.ui.Text,
				symlink = icons.ui.FileSymlink,
				bookmark = icons.ui.BookMark,
				folder = {
					arrow_closed = icons.ui.TriangleShortArrowRight,
					arrow_open = icons.ui.TriangleShortArrowDown,
					default = icons.ui.Folder,
					open = icons.ui.FolderOpen,
					empty = icons.ui.EmptyFolder,
					empty_open = icons.ui.EmptyFolderOpen,
					symlink = icons.ui.FolderSymlink,
					symlink_open = icons.ui.FolderOpen,
				},
				git = {
					unstaged = icons.git.FileUnstaged,
					staged = icons.git.FileStaged,
					unmerged = icons.git.FileUnmerged,
					renamed = icons.git.FileRenamed,
					untracked = icons.git.FileUntracked,
					deleted = icons.git.FileDeleted,
					ignored = icons.git.FileIgnored,
				},
			},
		},
		special_files = { "Cargo.toml", "Makefile", "README.md", "readme.md" },
		symlink_destination = true,
		update_focused_file = {
			enable = true,
			debounce_delay = 15,
			update_root = true,
			ignore_list = {},
		},
	},
}

M.configure = function()
	vim.g.loaded_netrw = 1
	vim.g.loaded_netrwPlugin = 1

	require('nvim-tree').setup(options)
end

return M
