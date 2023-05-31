local M = {}

local options = {
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

return M
