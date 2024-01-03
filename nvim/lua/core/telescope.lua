local M = {}
local builtin = require("telescope.builtin")
local icons = require("utils.icons")
local themes = require("telescope.themes")

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
			advanced_git_search = {
				diff_plugin = "diffview",
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
	telescope.load_extension("advanced_git_search")
	telescope.load_extension("noice")
	telescope.load_extension("zoxide")
	telescope.load_extension("neoclip")
	telescope.load_extension("frecency")
	telescope.load_extension("recent_files")
	telescope.load_extension("package_info")
	telescope.load_extension("ui-select")
end

local layouts = {
	full_cursor = function(height)
		return themes.get_cursor({
			layout_config = {
				width = function(_, max_columns, _)
					return max_columns - 6
				end,
				height = height or 12,
			},
		})
	end,
}

local find_project_files = function(opts)
	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

local open_lsp_definitions = function()
	local function exclude_react_index_d_ts(result)
		local uri = result.uri or result.targetUri
		if not uri then
			return false
		end
		local path = vim.uri_to_fname(uri)
		return not string.match(path, "react[/\\]index.d.ts$")
	end

	local results = vim.lsp.buf_request_sync(0, "textDocument/definition", vim.lsp.util.make_position_params(), 1000)

	for _client_id, response in pairs(results or {}) do
		if response.result and vim.tbl_islist(response.result) then
			-- Filter out unwanted results
			local filtered_results = vim.tbl_filter(exclude_react_index_d_ts, response.result)

			if #filtered_results == 1 then
				-- If there's exactly one result after filtering, jump to it directly
				vim.lsp.util.jump_to_location(filtered_results[1])
				return
			elseif #filtered_results > 1 then
				-- If there are multiple results after filtering, use Telescope to display them
				require("telescope.builtin").lsp_definitions(M.layouts.full_cursor())
				return
			end
		end
	end

	-- Fallback in case no results are found or some other unexpected behavior
	print("No definitions found")
end

M.layouts = layouts
M.helpers = {
	find_project_files = find_project_files,
	open_lsp_definitions = open_lsp_definitions,
}

return M
