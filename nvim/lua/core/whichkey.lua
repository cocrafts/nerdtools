local M = {}
local helper = require("utils.helper")
local icons = require("utils.icons")

local ai_keys = {
	e = { "<cmd>ChatGPTEditWithInstruction<CR>", "Edit with instruction" },
	g = { "<cmd>ChatGPTRun grammar_correction<CR>", "Grammar Correction" },
	t = { "<cmd>ChatGPTRun translate<CR>", "Translate" },
	k = { "<cmd>ChatGPTRun keywords<CR>", "Keywords" },
	d = { "<cmd>ChatGPTRun docstring<CR>", "Docstring" },
	a = { "<cmd>ChatGPTRun add_tests<CR>", "Add Tests" },
	o = { "<cmd>ChatGPTRun optimize_code<CR>", "Optimize Code" },
	s = { "<cmd>ChatGPTRun summarize<CR>", "Summarize" },
	f = { "<cmd>ChatGPTRun fix_bugs<CR>", "Fix Bugs" },
	x = { "<cmd>ChatGPTRun explain_code<CR>", "Explain Code" },
	c = { "<cmd>ChatGPTRun complete_code<CR>", "Complete Code" },
	r = { "<cmd>ChatGPTRun roxygen_edit<CR>", "Roxygen Edit" },
	l = { "<cmd>ChatGPTRun code_readability_analysis<CR>", "Code Readability Analysis" },
	h = { "<cmd>HurlRunner<CR>", "Hurl" },
}

local config = {
	setup = {
		icons = {
			breadcrumb = icons.ui.DoubleChevronRight,
			separator = icons.ui.BoldArrowRight,
			group = icons.ui.Package .. " ",
		},
	},
	nopts = {
		mode = "n",
		prefix = "<leader>",
		buffer = nil,
		silent = true,
		noremap = true,
		nowait = true,
	},
	vopts = {
		mode = "v",
		prefix = "<leader>",
		buffer = nil,
		silent = true,
		noremap = true,
		nowait = true,
	},
	nmaps = {
		w = { "<cmd>up<cr>", "save" },
		q = { "<cmd>q!<cr>", "quit" },
		["/"] = { "<Plug>(comment_toggle_linewise_current)", "Comment toggle current line" },
		c = { "<cmd>BufferKill<CR>", "Close Buffer" },
		C = { "<cmd>lua require('utils.helper').close_other_buffers()<CR>", "Close other buffers" },
		x = { "<cmd>Telescope neoclip theme=dropdown<CR>", "Clipboard history" },
		e = {
			function()
				require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() })
			end,
			"Toggle File Explorer",
		},
		E = { "<cmd>DBUIToggle<CR>", "Toggle Database Explorer" },
		z = { "<cmd>Telescope zoxide list<CR>", "Zoxide list" },
		u = { "<cmd>lua require('telescope').extensions.recent_files.pick()<CR>", "Recent files" },
		U = { "<cmd>Telescope git_status<CR>", "Open changed file" },
		i = { "<cmd>Telescope live_grep<CR>", "Live grep (lite)" },
		I = {
			function()
				local path = vim.api.nvim_buf_get_name(0)
				local directory = path:match("(.-)[^/]*$")
				require("telescope").extensions.live_grep_args.live_grep_args({
					prompt_title = string.format("Grep under: %s", directory),
					search_dirs = { directory },
				})
			end,
			"Live grep",
		},
		F = {
			function()
				local word_under_cursor = vim.fn.expand("<cword>")
				require("telescope").extensions.live_grep_args.live_grep_args({
					prompt_title = "Live grep (full)",
					default_text = word_under_cursor,
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--hidden",
					},
				})
			end,
			"Live grep (full)",
		},
		o = {
			function()
				helper.find_project_files({
					previewer = true,
					theme = "get_ivy",
					show_untracked = true,
				})
			end,
			"Find File",
		},
		O = { "<cmd>Telescope find_files<CR>", "File search" },
		b = {
			name = "Buffer",
			j = { "<cmd>bufferlinepick<cr>", "jump" },
			f = { "<cmd>telescope buffers theme=dropdown<cr>", "find" },
			w = { "<cmd>bufferwipeout<cr>", "wipeout" },
			p = { "<cmd>lua require('harpoon.ui').nav_next()<cr>", "previous harpoon" },
			n = { "<cmd>lua require('harpoon.ui').nav_prev()<cr>", "next harppoon" },
		},
		s = {
			mame = "SQL",
			c = { "<cmd>SqlsSwitchConnection<CR>", "Switch connection" },
			C = { "<cmd>SqlsShowConnections<CR>", "Show connections" },
			e = { "<cmd>SqlsExecuteQuery<CR>", "Execute query" },
			E = { "<cmd>SqlsExecuteQueryVertical<CR>", "Execute query vertical" },
			d = { "<cmd>SqlsSwitchDatabase<CR>", "Switch database" },
			D = { "<cmd>SqlsShowDatabases<CR>", "Show databases" },
			S = { "<cmd>SqlsShowSchemas<CR>", "Show schemas" },
			t = { "<cmd>SqlsSetType<CR>", "Set Type" },
			T = { "<cmd>SqlsShowTables<CR>", "Show tables" },
		},
		j = {
			name = "Jumps",
			d = {
				function()
					vim.diagnostic.open_float()
				end,
				"Open diagnostics",
			},
			D = { "<cmd>lua vim.diagnostic.reset()<CR>", "Clear dianogstics" },
			m = { "<cmd>MarkdownPreview<CR>", "Preview markdown" },
			j = { "<cmd>Telescope buffers theme=dropdown<cr>", "find" },
			p = { "<cmd>lua require('harpoon.ui').nav_next()<cr>", "previous harpoon" },
			n = { "<cmd>lua require('harpoon.ui').nav_prev()<cr>", "next harppoon" },
		},
		J = { "<cmd>Telescope buffers theme=dropdown<cr>", "find" },
		H = {
			function()
				require("telescope").extensions.harpoon.marks(helper.layouts.full_cursor())
			end,
			"Jumps telescope",
		},
		T = {
			name = "Treesitter",
			i = { ":InspectTree<CR>", "Inspect tree" },
			I = { ":TSConfigInfo<CR>", "Info" },
			h = { "<cmd>Inspect<CR>", "Highlight under cursor" },
			p = { "<cmd>TSPlaygroundToggle<CR>", "Playground" },
		},
		p = {
			name = "Package Manager",
			i = { "<cmd>Lazy install<CR>", "Install" },
			s = { "<cmd>Lazy sync<CR>", "Sync" },
			S = { "<cmd>Lazy clear<CR>", "Status" },
			c = { "<cmd>Lazy clean<CR>", "Clean" },
			u = { "<cmd>Lazy update<CR>", "Update" },
			p = { "<cmd>Lazy profile<CR>", "Profile" },
			l = { "<cmd>Lazy log<CR>", "Log" },
			d = { "<cmd>Lazy debug<CR>", "Debug" },
			m = { "<cmd>Mason<CR>", "Mason" },
		},
		f = {
			name = "Finder",
			f = { "<cmd>Telescope resume<CR>", "Resume last search" },
			h = { "<cmd>Telescope help_tags<CR>", "Help tags" },
			H = { "<cmd>Telescope highlights<CR>", "Find highlight groups" },
			r = { "<cmd>Telescope registers<CR>", "Registers" },
			k = { "<cmd>Telescope keymaps<CR>", "Keymaps" },
			c = { "<cmd>Telescope commands<CR>", "Commands" },
			C = { "<cmd>Telescope colorscheme<CR>", "Colorsheme" },
			m = { "<cmd>Telescope man_pages<CR>", "Man pages" },
			j = { "<cmd>Cheatsheet<CR>", "Cheatsheet" },
			e = { "<cmd>Telescope env<CR>", "Search environment variables" },
		},
		g = {
			name = "Git",
			j = { "<cmd>Telescope advanced_git_search diff_commit_file<CR>", "File affected commits" },
			l = { "<cmd>Telescope advanced_git_search search_log_content<CR>", "Search log contents" },
			L = { "<cmd>Telescope advanced_git_search diff_commit_line<CR>", "Line affected commits" },
			p = { "<cmd>lua require('gitsigns').preview_hunk()<CR>", "Preview hunk" },
			r = { "<cmd>lua require('gitsigns').reset_hunk()<CR>", "Reset hunk" },
			R = { "<cmd>lua require('gitsigns').reset_buffer()<CR>", "Reset buffer" },
			s = { "<cmd>lua require('gitsigns').stage_hunk()<CR>", "Stage hunk" },
			S = { "<cmd>lua require('gitsigns').undo_stage_hunk()<CR>", "Undo stage hunk" },
			w = { "<cmd>GitBlameOpenFileURL<CR>", "Open line url" },
			W = { "<cmd>GitBlameCopyFileURL<CR>", "Copy line url" },
			c = { "<cmd>GitBlameOpenCommitURL<CR>", "Open commit url" },
			C = { "<cmd>GitBlameCopyCommitURL<CR>", "Copy commit url" },
			b = { "<cmd>Telescope git_branches<CR>", "Checkout branch" },
			u = { "<cmd>Telescope git_commits<CR>", "Checkout commit" },
			U = { "<cmd>Telescope git_bcommits<CR>", "Checkout commit (current file)" },
			f = { ":DiffviewFileHistory %<CR>", "File history %" },
			F = { ":DiffviewFileHistory<CR>", "File history" },
			d = { ":DiffviewOpen<CR>", "Git diff" },
			q = { ":DiffviewClose<CR>", "Close Git diff" },
		},
		[";"] = { "<cmd>lua require('harpoon.mark').add_file()<CR>", "Add to harpoon" },
		[":"] = { "<cmd>lua require('harpoon.ui').toggle_quick_menu()<CR>", "Jumps menu" },
		a = vim.tbl_extend("force", {
			name = "AI/Ask ChatGPT bundle",
			j = { "<cmd>ChatGPT<CR>", "ChatGPT prompt" },
			u = { "<cmd>ChatGPTActAs<CR>", "ChatGPT prompt" },
		}, ai_keys),
		l = {
			name = "LSP",
			a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
			A = { "<cmd>lua vim.lsp.codelens.run()<CR>", "CodeLens Action" },
			e = { "<cmd>Telescope diagnostics bufnr=0<CR>", "Document Dianogstics" },
			f = { "<cmd>lua vim.lsp.buf.format()<CR>", "Format" },
			l = { "<cmd>LspInfo<CR>", "Info" },
			L = { "<cmd>LspInstallInfo<CR>", "Installer Info" },
			j = { "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", "Next Dianogstics" },
			k = { "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", "Previous Dianogstics" },
			r = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
			i = { "<cmd>Telescope lsp_references<CR>", "References" },
			I = { "<cmd>Telescope lsp_implementations<CR>", "Implementations" },
			d = { "<cmd>Telescope lsp_definitions<CR>", "Definitions" },
			D = { "<cmd>Telescope lsp_type_definitions<CR>", "Type definitions" },
			c = { "<cmd>Telescope lsp_incoming_calls<CR>", "Incoming calls" },
			C = { "<cmd>Telescope lsp_outgoing_calls<CR>", "Outgoing calls" },
			s = { "<cmd>Telescope lsp_document_symbols<CR>", "Document Symbols" },
			S = { "<cmd>Telescope lsp_workspace_symbols<CR>", "Workspace symbols" },
			p = { "<cmd>Telescope package_info<CR>", "Package actions" },
			o = { "<cmd>TwilightEnable<CR>", "Twilight on" },
			O = { "<cmd>TwilightDisable<CR>", "Twilight off" },
			h = { "<cmd>lua require('lsp-inlayhints').toggle()<CR>", "Toggle Inlay-hints" },
			H = { "<cmd>lua require('lsp-inlayhints').reset()<CR>", "Reset Inlay-hints" },
		},
		k = {
			name = "Terminal",
			k = { "<cmd>ToggleTerm direction=float<CR>", "Terminal float" },
			l = { "<cmd>ToggleTerm direction=vertical<CR>", "Terminal left" },
			j = { "<cmd>ToggleTerm direction=horizontal<CR>", "Terminal bottom" },
			h = { "<cmd>ToggleTerm direction=tab<CR>", "Terminal tab" },
		},
		r = {
			name = "Run",
			A = {
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunner")
					else
						print("Not available for this Buffer")
					end
				end,
				"Run all",
			},
			a = {
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunnerAt")
					else
						print("Not available for this Buffer")
					end
				end,
				"Run current block",
			},
			t = {
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunnerToEntry")
					else
						print("Not available for this Buffer")
					end
				end,
				"Run til current line",
			},
			v = {
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlVerbose")
					else
						print("Not available for this Buffer")
					end
				end,
				"Run in verbose mode",
			},
			l = {
				function()
					vim.cmd("HurlShowLastResponse")
				end,
				"Show last Hurl response",
			},
		},
	},
	vmaps = vim.tbl_extend("force", {}, ai_keys),
}

M.configure = function()
	local whichkey = require("which-key")

	whichkey.setup(config.setup)
	whichkey.register(config.nmaps, config.nopts)
	whichkey.register(config.vmaps, config.vopts)
end

return M
