return {
	{ "folke/tokyonight.nvim" },
	{ "lukas-reineke/onedark.nvim" },
	{ "catppuccin/nvim" },
	{
		"creativenull/efmls-configs-nvim",
		dependencies = { "neovim/nvim-lspconfig" },
	},
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
		dependencies = {
			{ "neovim/nvim-lspconfig" },
			{ "jose-elias-alvarez/null-ls.nvim" },
			{ "ms-jpq/coq_nvim", branch = "coq" },
			{ "ms-jpq/coq.artifacts", branch = "artifacts" },
			{ "ms-jpq/coq.thirdparty", branch = "3p" },
			{ "nvimdev/guard.nvim" },
			{
				"williamboman/mason.nvim",
				build = function()
					---@diagnostic disable-next-line: param-type-mismatch
					pcall(vim.cmd, "MasonUpdate")
				end,
			},
			{ "williamboman/mason-lspconfig.nvim" },
			{ "Hoffs/omnisharp-extended-lsp.nvim" },
			{ "jparise/vim-graphql" },
			{ "simrat39/rust-tools.nvim" },
			{
				"pmizio/typescript-tools.nvim",
				dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
			},
			{
				"ray-x/go.nvim",
				dependencies = {
					"ray-x/guihua.lua",
					"neovim/nvim-lspconfig",
					"nvim-treesitter/nvim-treesitter",
				},
				event = { "CmdlineEnter" },
				ft = { "go", "gomod", "gowork", "gotmpl" },
				build = ':lua require("go.install").update_all_sync()',
			},
			{
				"saecki/crates.nvim",
				dependencies = { "nvim-lua/plenary.nvim" },
				config = function()
					require("crates").setup()
				end,
			},
			{ "szebniok/tree-sitter-wgsl" },
			{ "lvimuser/lsp-inlayhints.nvim" },
			{
				"L3MON4D3/LuaSnip",
				dependencies = { "friendly-snippets" },
				build = "make install_jsregexp",
				event = "InsertEnter",
				config = function()
					require("core.luasnip").configure()
				end,
			},
			{ "hrsh7th/nvim-cmp" }, -- Autocompletion
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "hrsh7th/cmp-cmdline" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "rafamadriz/friendly-snippets", lazy = true },
		},
		config = function()
			require("core.lsp").configure()
			require("core.cmp").configure()
			require("core.mason").configure()
		end,
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		branch = "v3.x",
		cmd = "Neotree",
		config = function()
			require("core.neo-tree").configure()
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		event = "VimEnter",
		config = function()
			require("core.lualine").configure()
		end,
	},
	{ "folke/lazy.nvim", tag = "stable" },
	{ "folke/neodev.nvim", lazy = true },
	{ "folke/twilight.nvim" },
	{
		"folke/trouble.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
	},
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("core.noice").configure()
		end,
	},
	{
		"vuki656/package-info.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		config = function()
			require("core.package-info").configure()
		end,
	},
	{
		"folke/which-key.nvim",
		config = function()
			require("core.whichkey").configure()
		end,
	},
	{ "nvim-telescope/telescope-fzf-native.nvim", lazy = true, build = "make" },
	{ "nvim-lua/plenary.nvim", lazy = true },
	{ "kkharji/sqlite.lua", module = "sqlite" },
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = {
			{ "telescope-fzf-native.nvim" },
			{ "nvim-telescope/telescope-live-grep-args.nvim" },
			{ "LinArcX/telescope-env.nvim" },
			{ "jvgrootveld/telescope-zoxide" },
			{ "smartpde/telescope-recent-files" },
			{ "nvim-telescope/telescope-ui-select.nvim" },
			{
				"sudormrfbin/cheatsheet.nvim",
				dependencies = {
					{ "nvim-telescope/telescope.nvim" },
					{ "nvim-lua/popup.nvim" },
					{ "nvim-lua/plenary.nvim" },
				},
			},
			{
				"AckslD/nvim-neoclip.lua",
				dependencies = {
					{ "nvim-telescope/telescope.nvim" },
					{ "kkharji/sqlite.lua" },
				},
			},
			{
				"nvim-telescope/telescope-frecency.nvim",
				dependencies = {
					{ "nvim-tree/nvim-web-devicons" },
					{ "kkharji/sqlite.lua" },
				},
			},
		},
		cmd = "Telescope",
		lazy = true,
		config = function()
			require("core.telescope").configure()
		end,
	},
	{ "nvim-treesitter/playground", lazy = true },
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = "User FileOpened",
		config = function()
			require("core.treesitter").configure()
		end,
	},
	{ "f-person/git-blame.nvim" },
	{
		"sindrets/diffview.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.diffview").configure()
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		event = "User FileOpened",
		cmd = { "Gitsigns" },
		config = function()
			require("core.gitsigns").configure()
		end,
	},
	{
		"lewis6991/satellite.nvim",
		config = function()
			require("core.satellite").configure()
		end,
	},
	{
		"akinsho/bufferline.nvim",
		branch = "main",
		event = "User FileOpened",
		config = function()
			require("core.bufferline").configure()
		end,
	},
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("core.toggleterm").configure()
		end,
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("core.autopairs").configure()
		end,
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
	{ "windwp/nvim-ts-autotag" },
	{ "wakatime/vim-wakatime" },
	{
		"ethanholz/nvim-lastplace",
		config = function()
			require("nvim-lastplace").setup({})
		end,
	},
	{
		"numToStr/Comment.nvim",
		config = function()
			require("core.comment").configure()
		end,
		keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
		event = "User FileOpened",
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		version = "2.20.8",
		config = function()
			require("core.indent-blankline").configure()
		end,
		event = "User FileOpened",
	},
	{
		-- quick jump/search like vim-sneak
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					-- default options: exact mode, multi window, all directions, with a backdrop
					require("flash").jump()
				end,
				desc = "Flash",
			},
			{
				"S",
				mode = { "n", "o", "x" },
				function()
					require("flash").treesitter()
				end,
				desc = "Flash Treesitter",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
		},
	},
	{
		-- highlight other uses of the word under the cursor using regex matching
		"RRethy/vim-illuminate",
		config = function()
			require("core.illuminate").configure()
		end,
	},
	{
		-- highlight/preview color code
		"brenoprata10/nvim-highlight-colors",
		config = function()
			require("nvim-highlight-colors").setup({
				render = "foreground",
			})
		end,
	},
	{
		"mawkler/modicator.nvim",
		dependencies = {
			"folke/tokyonight.nvim",
			"catppuccin/nvim",
		},
		config = function()
			require("modicator").setup({
				show_warnings = true,
			})
		end,
	},
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup()
		end,
	},
}
