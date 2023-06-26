local M = {}
local builtin = require("telescope.builtin")

local options = {
	defaults = {
		layout_strategy = "horizontal",
		layout_config = {
			horizontal = {
				width = 0.98,
				height = 0.98,
			},
		},
	},
	pickers = {
		git_branches = {

		},
		git_commits = {

		},
		git_bcommits = {

		},
		find_files = {

		},
		oldfiles = {
			cwd_only = true,
		},
		colorscheme = {

		},
	},
	extensions = {
		fzf = {
			fuzzy = true,                -- false will only do exact matching
			override_generic_sorter = true, -- override the generic sorter
			override_file_sorter = true, -- override the file sorter
			case_mode = "smart_case",    -- or "ignore_case" or "respect_case"
		},
		frecency = {
			show_scores = false,
			show_unindexed = false,
		},
		recent_files = {
			only_cwd = true,
		},
	},
}

M.configure = function()
	local telescope = require("telescope")
	local neoclip = require("neoclip")

	---@diagnostic disable-next-line: redundant-parameter
	telescope.setup(options)
	neoclip.setup({ enable_persistent_history = true })

	telescope.load_extension("env")
	telescope.load_extension("fzf")
	telescope.load_extension("zoxide")
	telescope.load_extension("neoclip")
	telescope.load_extension("frecency")
	telescope.load_extension("recent_files")
end

M.find_project_files = function(opts)
	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

return M
