local M = {}
local helper = require("utils.helper")
local icons = require("utils.icons")

local config = {
	setup = {
		icons = {
			breadcrumb = icons.ui.DoubleChevronRight,
			separator = icons.ui.BoldArrowRight,
			group = icons.ui.Package .. " ",
		},
	},
}

M.configure = function()
	local whichkey = require("which-key")

	whichkey.setup(config.setup)
	whichkey.add({
		{
			mode = { "v" },
			{
				"<leader>F",
				function()
					-- Save current register content
					local save_reg = vim.fn.getreg('"')
					local save_regtype = vim.fn.getregtype('"')

					-- Yank visual selection
					vim.cmd('normal! "vy')
					local selected_text = vim.fn.getreg('"')

					-- Restore register
					vim.fn.setreg('"', save_reg, save_regtype)

					require("core.fzf").live_grep_args({
						prompt_title = "Live grep (full): ",
						search = selected_text,
					})
				end,
				desc = "Live grep (full) with selection",
			},
		},
		{
			mode = "n",
			{ "<leader>w", "<cmd>up<CR>", desc = "save" },
			{ "<leader>q", "<cmd>q!<CR>", desc = "quit" },
			{
				"<leader>/",
				"<Plug>(comment_toggle_linewise_current)",
				desc = "Comment toggle current line",
			},
			{ "<leader>c", "<cmd>BufferKill<CR>",     desc = "Close buffer" },
			{
				"<leader>C",
				"<cmd>lua require('utils.helper').close_other_buffers()<CR>",
				desc = "Close other buffers",
			},
			{ "<leader>x", "<cmd>FzfLua neoclip<CR>", desc = "Clipboard history" },
			{
				"<leader>e",
				function()
					require("neo-tree.command").execute({ toggle = true, dir = vim.loop.cwd() })
				end,
				desc = "Clipboard history",
			},
			{
				"<leader>E",
				"<cmd>DBUIToggle<CR>",
				desc = "Toggle Database Explorer",
			},
			{
				"<leader>R",
				"<cmd>e<CR>",
				desc = "Reload buffer",
			},
			{
				"<leader>z",
				"<cmd>FzfLua files cwd=~<CR>",
				desc = "Zoxide list (use z command)",
			},
			{ "<leader>u",  "<cmd>lua require('core.fzf').recent_files()<CR>", desc = "Recent files" },
			{
				"<leader>U",
				"<cmd>FzfLua git_status<CR>",
				desc = "Open changed file",
			},
			{
				"<leader>i",
				"<cmd>FzfLua live_grep<CR>",
				desc = "Live grep (lite)",
			},
			{
				"<leader>I",
				function()
					local path = vim.api.nvim_buf_get_name(0)
					local directory = path:match("(.-)[^/]*$")
					require("core.fzf").live_grep_args({
						prompt_title = string.format("Grep under: %s", directory),
						search_dirs = { directory },
					})
				end,
				desc = "Live grep",
			},
			{
				"<leader>F",
				function()
					local word_under_cursor = vim.fn.expand("<cword>")
					require("core.fzf").live_grep_args({
						prompt_title = "Live grep (full): ",
						search = word_under_cursor,
					})
				end,
				desc = "Live grep (full) ",
			},
			{
				"<leader>o",
				function()
					require("fzf-lua").files({
						previewer = true,
						git_icons = true,
						file_icons = true,
					})
				end,
				desc = "Find File",
			},
			{ "<leader>O",  "<cmd>FzfLua files<CR>",                           desc = "File search" },

			{ "<leader>b",  group = "Buffer" },
			{ "<leader>bj", "<cmd>bufferlinepick<CR>",                         desc = "jump" },
			{ "<leader>bf", "<cmd>FzfLua buffers<CR>",                         desc = "find" },
			{ "<leader>bw", "<cmd>bufferwipeout<CR>",                          desc = "wipeout" },

			{ "<leader>j",  group = "Jumps" },
			{
				"<leader>jd",
				function()
					vim.diagnostic.open_float()
				end,
				desc = "Open diagnostics",
			},
			{ "<leader>jD", "<cmd>lua vim.diagnostic.reset()<CR>", desc = "Clear diagnostics" },
			{ "<leader>jm", "<cmd>MarkdownPreviewToggle<CR>",      desc = "Preview markdown" },
			{ "<leader>J",  "<cmd>FzfLua buffers<CR>",             desc = "Find buffers" },

			{ "<leader>T",  group = "Treesitter" },
			{ "<leader>Ti", ":InspectTree<CR>",                    desc = "Inspect tree" },
			{ "<leader>TI", ":TSConfigInfo<CR>",                   desc = "Info" },
			{
				"<leader>Th",
				"<cmd>Inspect<CR>",
				desc = "Highlight under cursor",
			},
			{ "<leader>Tp", "<cmd>TSPlaygroundToggle<CR>", desc = "Playground" },

			{ "<leader>p",  group = "Package manager" },
			{ "<leader>pi", "<cmd>Lazy install<CR>",       desc = "Install" },
			{ "<leader>ps", "<cmd>Lazy sync<CR>",          desc = "Sync" },
			{ "<leader>pS", "<cmd>Lazy clear<CR>",         desc = "Status" },
			{ "<leader>pc", "<cmd>Lazy clean<CR>",         desc = "Clean" },
			{ "<leader>pu", "<cmd>Lazy update<CR>",        desc = "Update" },
			{ "<leader>pp", "<cmd>Lazy profile<CR>",       desc = "Profile" },
			{ "<leader>pl", "<cmd>Lazy log<CR>",           desc = "Log" },
			{ "<leader>pd", "<cmd>Lazy debug<CR>",         desc = "Debug" },
			{ "<leader>pm", "<cmd>Mason<CR>",              desc = "Mason" },

			{ "<leader>f",  group = "Finder" },
			{ "<leader>ff", "<cmd>FzfLua resume<CR>",      desc = "Resume last search" },
			{ "<leader>fh", "<cmd>FzfLua help_tags<CR>",   desc = "Help tags" },
			{
				"<leader>fH",
				"<cmd>FzfLua highlights<CR>",
				desc = "Find highlight groups",
			},
			{ "<leader>fr", "<cmd>FzfLua registers<CR>",    desc = "Registers" },
			{ "<leader>fk", "<cmd>FzfLua keymaps<CR>",      desc = "Keymaps" },
			{ "<leader>fc", "<cmd>FzfLua commands<CR>",     desc = "Commands" },
			{ "<leader>fC", "<cmd>FzfLua colorschemes<CR>", desc = "Colorsheme" },
			{ "<leader>fm", "<cmd>FzfLua manpages<CR>",     desc = "Man pages" },
			{ "<leader>fj", "<cmd>Cheatsheet<CR>",          desc = "Cheatsheet" },
			{
				"<leader>fe",
				"<cmd>FzfLua lines<CR>",
				desc = "Search lines in buffers",
			},

			{ "<leader>g",  group = "Git" },
			{
				"<leader>gj",
				"<cmd>Telescope advanced_git_search diff_commit_file<CR>",
				desc = "File affected commits",
			},
			{ "<leader>gl", "<cmd>Telescope advanced_git_search search_log_content<CR>", desc = "Search log contents" },
			{
				"<leader>gL",
				"<cmd>Telescope advanced_git_search diff_commit_line<CR>",
				desc = "Line affected commits",
			},
			{ "<leader>gp", "<cmd>lua require('gitsigns').preview_hunk()<CR>",    desc = "Preview hunk" },
			{ "<leader>gr", "<cmd>lua require('gitsigns').reset_hunk()<CR>",      desc = "Reset hunk" },
			{ "<leader>gR", "<cmd>lua require('gitsigns').reset_buffer()<CR>",    desc = "Reset buffer" },
			{ "<leader>gs", "<cmd>lua require('gitsigns').stage_hunk()<CR>",      desc = "Stage hunk" },
			{ "<leader>gS", "<cmd>lua require('gitsigns').undo_stage_hunk()<CR>", desc = "Undo stage hunk" },
			{ "<leader>gw", "<cmd>GitBlameOpenFileURL<CR>",                       desc = "Open line url" },
			{ "<leader>gW", "<cmd>GitBlameCopyFileURL<CR>",                       desc = "Copy line url" },
			{ "<leader>gc", "<cmd>GitBlameOpenCommitURL<CR>",                     desc = "Open commit url" },
			{ "<leader>gC", "<cmd>GitBlameCopyCommitURL<CR>",                     desc = "Copy commit url" },
			{ "<leader>gb", "<cmd>FzfLua git_branches<CR>",                       desc = "Checkout branch" },
			{ "<leader>gu", "<cmd>FzfLua git_commits<CR>",                        desc = "Checkout commit" },
			{
				"<leader>gU",
				"<cmd>FzfLua git_bcommits<CR>",
				desc = "Checkout commit (current file)",
			},
			{ "<leader>gf", ":DiffviewFileHistory %<CR>",             desc = "File history %" },
			{ "<leader>gF", ":DiffviewFileHistory<CR>",               desc = "File history" },
			{ "<leader>gd", ":DiffviewOpen<CR>",                      desc = "Git diff" },
			{ "<leader>gq", ":DiffviewClose<CR>",                     desc = "Close Git diff" },
			{ "<leader>g;", ":BlameToggle<CR>",                       desc = "Toggle Blame" },

			{ "<leader>l",  group = "LSP" },
			{ "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code Action" },
			{ "<leader>lA", "<cmd>lua vim.lsp.codelens.run()<CR>",    desc = "CodeLens Action" },
			{
				"<leader>le",
				"<cmd>FzfLua diagnostics_document<CR>",
				desc = "Document Dianogstics",
			},
			{ "<leader>lf", "<cmd>lua vim.lsp.buf.format()<CR>",       desc = "Format" },
			{ "<leader>ll", "<cmd>LspInfo<CR>",                        desc = "Info" },
			{ "<leader>lL", "<cmd>LspInstallInfo<CR>",                 desc = "Installer Info" },
			{ "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<CR>", desc = "Next Dianogstics" },
			{
				"<leader>lk",
				"<cmd>lua vim.diagnostic.goto_prev()<CR>",
				desc = "Previous Dianogstics",
			},
			{ "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<CR>",        desc = "Rename" },
			{
				"<leader>li",
				function()
					require("fzf-lua").lsp_references({
						winopts = {
							relative = "cursor",
							width = 0.6,
							height = 0.5,
							row = 1,
							col = 0,
							preview = {
								vertical = "up:60%",
							},
						},
					})
				end,
				desc = "References",
			},
			{ "<leader>lI", "<cmd>FzfLua lsp_implementations<CR>",      desc = "Implementations" },
			{ "<leader>ld", "<cmd>FzfLua lsp_definitions<CR>",          desc = "Definitions" },
			{ "<leader>lD", "<cmd>FzfLua lsp_typedefs<CR>",             desc = "Type definitions" },
			{ "<leader>lc", "<cmd>FzfLua lsp_incoming_calls<CR>",       desc = "Incoming calls" },
			{ "<leader>lC", "<cmd>FzfLua lsp_outgoing_calls<CR>",       desc = "Outgoing calls" },
			{ "<leader>ls", "<cmd>FzfLua lsp_document_symbols<CR>",     desc = "Document Symbols" },
			{ "<leader>lS", "<cmd>FzfLua lsp_workspace_symbols<CR>",    desc = "Workspace symbols" },
			{ "<leader>lp", "<cmd>Telescope package_info<CR>",          desc = "Package actions" },
			{ "<leader>lh", "<cmd>InlayHintsEnable<CR>",                desc = "Enable Inlay-hints" },
			{ "<leader>lH", "<cmd>InlayHintsDisable<CR>",               desc = "Disable Inlay-hints" },

			{ "<leader>k",  group = "Terminal" },
			{ "<leader>kk", "<cmd>ToggleTerm direction=float<CR>",      desc = "Terminal float" },
			{ "<leader>kl", "<cmd>ToggleTerm direction=vertical<CR>",   desc = "Terminal left" },
			{ "<leader>kj", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Terminal bottom" },
			{ "<leader>kh", "<cmd>ToggleTerm direction=tab<CR>",        desc = "Terminal tab" },

			{ "<leader>r",  group = "Terminal" },
			{
				"<leader>rA",
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunner")
					else
						print("Not available for this Buffer")
					end
				end,
				desc = "Run all",
			},
			{
				"<leader>ra",
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunnerAt")
					else
						print("Not available for this Buffer")
					end
				end,
				desc = "Run current block",
			},
			{
				"<leader>rt",
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlRunnerToEntry")
					else
						print("Not available for this Buffer")
					end
				end,
				desc = "Run til current line",
			},
			{
				"<leader>rv",
				function()
					local bufnr = vim.api.nvim_get_current_buf()
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

					if filetype == "hurl" then
						vim.cmd("HurlVerbose")
					else
						print("Not available for this Buffer")
					end
				end,
				desc = "Run in verbose mode",
			},
			{
				"<leader>rl",
				function()
					vim.cmd("HurlShowLastResponse")
				end,
				desc = "Show last Hurl response",
			},
		},
	})
end

return M
