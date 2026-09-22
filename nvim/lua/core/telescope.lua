local M = {}
local icons = require("utils.icons")

M.configure = function()
	local telescope = require("telescope")

	telescope.setup({
		defaults = {
			prompt_prefix = string.format(" %s ", icons.ui.Search),
			selection_caret = string.format("%s ", icons.ui.PointArrow),
			layout_strategy = "horizontal",
			layout_config = {
				horizontal = {
					width = 0.98,
					height = 0.98,
				},
			},
		},
		pickers = {
			git_branches = {},
			git_commits = {},
			git_bcommits = {},
			find_files = {},
			oldfiles = {
				cwd_only = true,
			},
			colorscheme = {},
		},
		extensions = {
			fzf = {
				fuzzy = true,
				override_generic_sorter = true,
				override_file_sorter = true,
				case_mode = "smart_case",
			},
			recent_files = {
				only_cwd = true,
			},
			["ui-select"] = {
				require("telescope.themes").get_dropdown({}),
			},
		},
	})

	telescope.load_extension("fzf")
	telescope.load_extension("recent_files")
	telescope.load_extension("ui-select")
end

M.files = function(opts)
	require("telescope.builtin").find_files(opts or {})
end

M.live_grep = function(opts)
	require("telescope.builtin").live_grep(opts or {})
end

M.buffers = function(opts)
	require("telescope.builtin").buffers(opts or {})
end

M.changed_git_files = function()
	require("telescope.builtin").git_status()
end

M.recent_files = function()
	require("telescope").extensions.recent_files.pick()
end

M.live_grep_args = function(opts)
	opts = opts or {}
	if opts.search then
		opts.default_text = opts.search
		opts.search = nil
	end
	require("telescope").extensions.live_grep_args.live_grep_args(opts)
end

return M
