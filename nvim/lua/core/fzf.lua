local M = {}
local icons = require("utils.icons")

M.configure = function()
	local fzf = require("fzf-lua")
	local neoclip = require("neoclip")

	-- Configure chafa for image preview
	local img_previewer = nil
	if vim.fn.executable("chafa") == 1 then
		img_previewer = { "chafa", "{file}", "--format=symbols" }
	end

	-- Setup fzf-lua with telescope profile for familiar look/feel
	fzf.setup({
		-- Use telescope profile as base with some customizations
		"telescope",
		winopts = {
			height = 0.97,
			width = 0.98,
			row = 0.5,
			col = 0.5,
			border = "rounded",
			backdrop = false,
			preview = {
				layout = "flex",
				vertical = "down:45%",
				horizontal = "right:60%",
			},
		},
		-- Image preview with chafa
		previewers = img_previewer and {
			builtin = {
				extensions = {
					["png"] = img_previewer,
					["jpg"] = img_previewer,
					["jpeg"] = img_previewer,
					["gif"] = img_previewer,
					["webp"] = img_previewer,
				},
			},
		} or nil,
		fzf_opts = {
			["--layout"] = "reverse",
			["--info"] = "inline",
			["--prompt"] = string.format(" %s ", icons.ui.Search),
			["--pointer"] = string.format("%s", icons.ui.PointArrow),
		},
		keymap = {
			fzf = {
				["ctrl-q"] = "select-all+accept",
			},
		},
		-- File pickers
		files = {
			prompt = "Files: ",
			cwd_prompt = false,
			git_icons = true,
			file_icons = true,
		},
		oldfiles = {
			prompt = "History: ",
			cwd_only = true,
			include_current_session = true,
		},
		-- Search pickers
		grep = {
			prompt = "Grep: ",
			rg_opts =
			"--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --follow --glob '!node_modules' -e",
		},
		live_grep = {
			prompt = "Live Grep: ",
			cmd =
			"rg --column --line-number --no-heading --color=always --smart-case --max-columns=4096 --follow --glob '!node_modules'",
		},
		-- LSP pickers
		lsp = {
			prompt = "LSP: ",
			symbols = {
				symbol_style = 1, -- 1: icon+kind, 2: icon, 3: kind
			},
		},
		-- Git pickers
		git = {
			status = {
				prompt = "Git Status: ",
				preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
			},
			commits = {
				prompt = "Git Commits: ",
				preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
			},
			bcommits = {
				prompt = "Buffer Commits: ",
				preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
			},
			branches = {
				prompt = "Git Branches: ",
			},
		},
		-- Buffers picker
		buffers = {
			prompt = "Buffers: ",
			file_icons = true,
			git_icons = true,
		},
		-- Colorscheme picker
		colorschemes = {
			prompt = "Colorschemes: ",
			live_preview = true,
		},
	})

	-- Setup neoclip with fzf-lua support
	neoclip.setup({
		enable_persistent_history = true,
		keys = {
			fzf = {
				select = "default",
				paste = "ctrl-j",
				paste_behind = "ctrl-k",
				delete = "ctrl-d",
				edit = "ctrl-e",
				custom = {},
			},
		},
	})

	-- Register fzf-lua as the default UI select
	fzf.register_ui_select()
end

-- Helper function for live grep with args (similar to telescope-live-grep-args)
M.live_grep_args = function(opts)
	opts = opts or {}
	require("fzf-lua").live_grep({
		prompt = opts.prompt_title or "Live Grep ",
		search_dirs = opts.search_dirs,
		search = opts.search or "",
	})
end

-- Helper for recent files (similar to telescope-recent-files)
M.recent_files = function()
	require("fzf-lua").oldfiles({
		cwd_only = true,
		include_current_session = true,
		winopts = {
			width = 0.6,
			height = 0.6,
			row = 0.5,
			col = 0.5,
			preview = {
				vertical = "up:60%",
			},
		},
	})
end

-- Helper for changed file (tracked by Git)
M.changed_git_files = function()
	require("fzf-lua").git_status({
		winopts = {
			width = 0.6,
			height = 0.6,
			row = 0.5,
			col = 0.5,
			preview = {
				vertical = "up:60%",
			},
		},
	})
end

return M
