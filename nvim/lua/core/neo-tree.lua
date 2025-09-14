local M = {}
local icons = require("utils.icons")
local uv = vim.loop

M.open = function(path)
	if uv.os_uname().sysname == "Darwin" then
		os.execute('open "' .. path .. '"')
	elseif uv.os_uname().sysname == "Linux" then
		os.execute('xdg-open "' .. path .. '"')
	elseif uv.os_uname().sysname == "Windows" then
		os.execute('start "" "' .. path .. '"')
	else
		error("Unsupported operating system")
	end
end

M.configure = function()
	local neotree = require("neo-tree")

	-- Auto-center neo-tree when switching buffers
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local file = vim.fn.expand("%:p")
			if file == "" or vim.fn.filereadable(file) ~= 1 then
				return
			end

			vim.defer_fn(function()
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
						-- Navigate to file and center
						pcall(require("neo-tree.sources.filesystem").navigate, nil, file)
						vim.defer_fn(function()
							vim.api.nvim_win_call(win, function()
								vim.cmd("normal! zz")
							end)
						end, 100)
						break
					end
				end
			end, 50)
		end,
	})

	require("nvim-web-devicons").set_icon({
		d2 = {
			icon = "", -- or choose any Nerd Font icon you like
			color = "#FFD700", -- gold/yellow
			cterm_color = "220",
			name = "D2",
		},
	})

	neotree.setup({
		close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
		popup_border_style = "rounded",
		enable_git_status = true,
		enable_diagnostics = true,
		open_files_do_not_replace_types = { "terminal", "trouble", "qf", "Outline" }, -- when opening files, do not use windows containing these filetypes or buftypes
		sort_case_insensitive = true,                                               -- used when sorting files and directories in the tree
		window = {
			position = "left",
			width = 32,
			mappings = {
				["<space>"] = "none",
				["o"] = {
					command = function(state)
						local node = state.tree:get_node()
						M.open(node.path)
					end,
					nowait = true,
				},
			},
		},
		source_selector = {
			winbar = false, -- bar to swap between Files, Buffer, Git
			status_line = true,
			padding = 0,
			show_scrolled_off_parent_node = true,
			show_separator_on_edge = false,
		},
		filesystem = {
			commands = {},
			follow_current_file = {
				enabled = true,
			},
			group_empty_dirs = false,
			-- "open_default", netrw disabled, opening a directory opens neo-tree in whatever position is specified in window.position
			-- "open_current", netrw disabled, opening a directory opens within the window like netrw would, regardless of window.position
			-- "disabled", netrw left alone, neo-tree does not handle opening dirs
			hijack_netrw_behavior = "open_default",
			use_libuv_file_watcher = true, -- This will use the OS level file watchers to detect changes instead of relying on nvim autocmd events.
			filtered_items = {
				visible = false,          -- when true, they will just be displayed differently than normal items
				hide_dotfiles = true,
				hide_gitignored = true,
				hide_hidden = true, -- for Windows only
				hide_by_name = {
					"node_modules",
				},
				hide_by_pattern = {},
				always_show = {
					".gitignored",
				},
				never_show = {
					".DS_Store",
				},
				never_show_by_pattern = {},
			},
		},
		default_component_configs = {
			container = {
				enable_character_fade = true,
			},
			indent = {
				indent_size = 2,
				padding = 1,
				with_marker = true,
				indent_marker = "│",
				last_indent_marker = "└",
				highlight = "NeoTreeIndentMarker",
			},
			icon = {
				folder_closed = icons.ui.Folder,
				folder_open = icons.ui.FolderOpen,
				folder_empty = icons.ui.EmptyFolder,
			},
			modified = {
				symbol = icons.git.LineModified,
				highlight = "NeoTreeModified",
			},
			name = {
				trailing_slash = false,
				use_git_status_colors = true,
				highlight = "NeoTreeFileName",
			},
			git_status = {
				symbols = {
					-- Change type
					added = "",                    -- or "✚", but this is redundant info if you use git_status_colors on the name
					modified = "",                 -- or "", but this is redundant info if you use git_status_colors on the name
					deleted = icons.misc.CircleCrossed, -- this can only be used in the git_status source
					renamed = icons.misc.CircleEdit, -- this can only be used in the git_status source
					-- Status type
					untracked = icons.misc.Dot,
					ignored = icons.misc.Dot,
					unstaged = icons.misc.Dot,
					staged = icons.misc.Dot,
					conflict = icons.git.FileUnmerged,
				},
			},
			diagnostics = {
				symbols = {
					hint = icons.diagnostics.Hint,
					info = icons.diagnostics.Information,
					warn = icons.diagnostics.Warning,
					error = icons.diagnostics.Error,
				},
				highlights = {
					hint = "DiagnosticSignHint",
					info = "DiagnosticSignInfo",
					warn = "DiagnosticSignWarn",
					error = "DiagnosticSignError",
				},
			},
		},
		document_symbols = {
			kinds = {
				File = { icon = icons.kind.File, hl = "Tag" },
				Namespace = { icon = icons.kind.Namespace, hl = "Include" },
				Package = { icon = icons.kind.Package, hl = "Label" },
				Class = { icon = icons.kind.Class, hl = "Include" },
				Property = { icon = icons.kind.Property, hl = "@property" },
				Enum = { icon = icons.kind.Enum, hl = "@number" },
				Function = { icon = icons.kind.Function, hl = "Function" },
				String = { icon = icons.kind.String, hl = "String" },
				Number = { icon = icons.kind.Number, hl = "Number" },
				Array = { icon = icons.kind.Array, hl = "Type" },
				Object = { icon = icons.kind.Object, hl = "Type" },
				Key = { icon = icons.kind.Key, hl = "" },
				Struct = { icon = icons.kind.Struct, hl = "Type" },
				Operator = { icon = icons.kind.Operator, hl = "Operator" },
				TypeParameter = { icon = icons.kind.TypeParameter, hl = "Type" },
				StaticMethod = { icon = icons.kind.Method, hl = "Function" },
			},
		},
	})
end

return M
