local M = {}
local builtin = require("telescope.builtin")

local options = {
	pickers = {
		git_branches = {
			theme = "dropdown",
		},
		git_commits = {
			theme = "dropdown",
		},
		git_bcommits = {
			theme = "dropdown",
		},
		find_files = {
			theme = "dropdown",
		},
		oldfiles = {
			theme = "dropdown",
			cwd_only = true,
		},
		colorscheme = {
			theme = "dropdown",
		},
	},
	extensions = {
		fzf = {
			fuzzy = true,                -- false will only do exact matching
			override_generic_sorter = true, -- override the generic sorter
			override_file_sorter = true, -- override the file sorter
			case_mode = "smart_case",    -- or "ignore_case" or "respect_case"
		},
	},
}

M.configure = function()
	local telescope = require("telescope")

	---@diagnostic disable-next-line: redundant-parameter
	telescope.setup(options)
	telescope.load_extension("fzf")
end

M.find_project_files = function(opts)
	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

return M
