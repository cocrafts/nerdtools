local M = {}
local builtin = require("telescope.builtin")
local icons = require("utils.icons")

M.configure = function()
	local telescope = require("telescope")
	local neoclip = require("neoclip")

	telescope.setup({
		defaults = {
			prompt_prefix = string.format(" %s  ", icons.ui.Search),
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
				fuzzy = true, -- false will only do exact matching
				override_generic_sorter = true, -- override the generic sorter
				override_file_sorter = true, -- override the file sorter
				case_mode = "smart_case", -- or "ignore_case" or "respect_case"
			},
			frecency = {
				show_scores = false,
				show_unindexed = false,
			},
			recent_files = {
				only_cwd = true,
			},
			package_info = {
				theme = "dropdown",
			},
			["ui-select"] = {
				require("telescope.themes").get_dropdown({
					-- more opts
				}),
			},
		},
	})

	neoclip.setup({
		enable_persistent_history = true,
		keys = {
			telescope = {
				i = {
					select = "<cr>",
					paste = "<c-j>",
					paste_behind = "<c-k>",
					replay = "<c-q>", -- replay a macro
					delete = "<c-d>", -- delete an entry
					edit = "<c-e>", -- edit an entry
					custom = {},
				},
				n = {
					select = "<cr>",
					paste = "j",
					paste_behind = "k",
					replay = "q",
					delete = "d",
					edit = "e",
					custom = {},
				},
			},
		},
	})

	telescope.load_extension("env")
	telescope.load_extension("fzf")
	telescope.load_extension("zoxide")
	telescope.load_extension("neoclip")
	telescope.load_extension("frecency")
	telescope.load_extension("recent_files")
	telescope.load_extension("package_info")
	telescope.load_extension("ui-select")
end

M.find_project_files = function(opts)
	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

return M
