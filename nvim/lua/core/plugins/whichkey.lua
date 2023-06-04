local M = {}

local config = {
	setup = {
		icons = {
			breadcrumb = "»",
			separator = "",
			group = " ",
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
		["w"] = { "<cmd>w!<cr>", "save" },
		["q"] = { "<cmd>q!<cr>", "quit" },
		["/"] = { "<Plug>(comment_toggle_linewise_current)", "Comment toggle current line" },
		["c"] = { "<cmd>BufferKill<CR>", "Close Buffer" },
		["e"] = { "<cmd>NvimTreeToggle<CR>", "Explorer" },
		["o"] = { "<cmd>Telescope find_files<CR>", "File search" },
		["i"] = { "<cmd>Telescope live_grep theme=get_ivy<CR>", "Live grep search" },
		["u"] = { "<cmd>Telescope oldfiles<CR>", "Recent files" },
		b = {
			name = "Buffer",
			j = { "<cmd>BufferLinePick<CR>", "Jump" },
			f = { "<cmd>Telescope buffers theme=dropdown<CR>", "Find" },
			w = { "<cmd>BufferWipeout<CR>", "Wipeout" },
			h = { "<cmd>BufferLineCloseLeft<CR>", "Close all to the left" },
			l = { "<cmd>BufferLineCloseRight<CR>", "Close all to the right" },
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
			f = {
				function()
					require("core.plugins.telescope").find_project_files { previewer = true, theme = "get_ivy" }
				end,
				"Find File",
			},
			l = { "<cmd>NvimTreeFindFile<CR>", "Locate file" },
			h = { "<cmd>Telescope help_tags<CR>", "Help tags" },
			H = { "<cmd>Telescope highlights<CR>", "Find highlight groups" },
			r = { "<cmd>Telescope registers<CR>", "Registers" },
			k = { "<cmd>Telescope keymaps<CR>", "Keymaps" },
			t = { "<cmd>Telescope colorscheme<CR>", "Colorsheme" },
			c = { "<cmd>Telescope commands<CR>", "Commands" },
			m = { "<cmd>Telescope man_pages<CR>", "Man pages" },
			s = { "<cmd>Telescope resume<CR>", "Resume last search" },
		},
		G = {
			name = "Git Fugitive",
			s = { "<cmd>G<CR>", "Status" },
			c = { "<cmd>G commit<CR>", "Commit" },
			p = { "<cmd>G push<CR>", "Push" },
		},
		g = {
			name = "Git",
			j = { "<cmd>lua require('gitsigns').next_hunk()<CR>", "Next hunk" },
			k = { "<cmd>lua require('gitsigns').prev_hunk()<CR>", "Previous hunk" },
			p = { "<cmd>lua require('gitsigns').preview_hunk()<CR>", "Preview hunk" },
			r = { "<cmd>lua require('gitsigns').reset_hunk()<CR>", "Reset hunk" },
			R = { "<cmd>lua require('gitsigns').reset_buffer()<CR>", "Reset buffer" },
			s = { "<cmd>lua require('gitsigns').stage_hunk()<CR>", "Stage hunk" },
			u = { "<cmd>lua require('gitsigns').undo_stage_hunk()<CR>", "Undo stage hunk" },
			o = { "<cmd>Telescope git_status<CR>", "Open changed file" },
			b = { "<cmd>Telescope git_branches<CR>", "Checkout branch" },
			c = { "<cmd>Telescope git_commits<CR>", "Checkout commit" },
			C = { "<cmd>Telescope git_bcommits<CR>", "Checkout commit (current file)" },
			l = { ":Neogit<CR>", "Commit" },
			L = { ":Neogit commit<CR>", "Push" },
			f = { ":DiffviewFileHistory %<CR>", "File history %" },
			F = { ":DiffviewFileHistory<CR>", "File history" },
			d = { ":DiffviewOpen<CR>", "Git diff" },
			q = { ":DiffviewClose<CR>", "Close Git diff" },
		},
		l = {
			name = "LSP",
			a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
			d = { "<cmd>Telescope diagnostics bufnr=0<CR>", "Document Dianogstics" },
			f = { "<cmd>lua vim.lsp.buf.formatting()<CR>", "Format" },
			i = { "<cmd>LspInfo<CR>", "Info" },
			I = { "<cmd>LspInstallInfo<CR>", "Installer Info" },
			j = { "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", "Next Dianogstics" },
			k = { "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", "Previous Dianogstics" },
			l = { "<cmd>lua vim.lsp.codelens.run()<CR>", "CodeLens Action" },
			r = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
			s = { "<cmd>Telescope lsp_document_symbols<CR>", "Document Symbols" },
			S = { "<cmd>Telescope lsp_workspace_symbols<CR>", "Workspace symbols" },
		}
	},
	vmaps = {

	},
}

M.configure = function()
	local whichkey = require("which-key")

	whichkey.setup(config.setup)
	whichkey.register(config.nmaps, config.nopts)
	-- whichkey.register(config.vmaps, config.vopts)
end

return M
