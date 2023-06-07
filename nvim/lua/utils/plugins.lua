return {
	{ "wbthomason/packer.nvim" },
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v2.x",
		dependencies = {
			{ "neovim/nvim-lspconfig" },
			{
				"williamboman/mason.nvim",
				build = function()
					pcall(vim.cmd, 'MasonUpdate')
				end,
			},
			{ "j-hui/fidget.nvim" }, -- lsp loading status
			{ "williamboman/mason-lspconfig.nvim" },
			{ "simrat39/rust-tools.nvim" },
			{
				"saecki/crates.nvim",
				requires = { "nvim-lua/plenary.nvim" },
				config = function()
					require("crates").setup()
				end,
			},
			{
				"L3MON4D3/LuaSnip",
				dependencies = { "friendly-snippets" },
				build = "make install_jsregexp",
				event = "InsertEnter",
				config = function()
					require("luasnip.loaders.from_lua").lazy_load()
					require("luasnip.loaders.from_snipmate").lazy_load()
				end,
			},
			{ "ray-x/lsp_signature.nvim" },
			{ "lvimuser/lsp-inlayhints.nvim" },
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
			require("core.lsp.cmp").configure()
		end,
	},
	{
		"VidocqH/lsp-lens.nvim",
		config = function()
			require("lsp-lens").setup({})
		end,
	},
	{
		"nvim-tree/nvim-tree.lua",
		requires = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.plugins.nvim-tree").configure()
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		event = "VimEnter",
		config = function()
			require("core.lualine").configure()
		end,
	},
	{ "folke/lazy.nvim",       tag = "stable" },
	{ "folke/neodev.nvim",     lazy = true },
	{
		"folke/twilight.nvim",
		config = function()
			vim.cmd(":TwilightEnable")
		end,
	},
	{
		"zbirenbaum/neodim",
		event = "LspAttach",
		config = function()
			require("neodim").setup({
				alpha = 0.3,
			})
		end,
	},
	{
		"folke/which-key.nvim",
		config = function()
			require("core.plugins.whichkey").configure()
		end,
	},
	{
		"folke/tokyonight.nvim",
		config = function()
			require("core.plugins.tokyonight").configure()
		end,
	},
	{ "lukas-reineke/onedark.nvim" },
	{ "nvim-telescope/telescope-fzf-native.nvim", lazy = true, build = "make" },
	{ "nvim-lua/plenary.nvim",                    lazy = true },
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = { "telescope-fzf-native.nvim" },
		cmd = "Telescope",
		lazy = true,
		config = function()
			require("core.plugins.telescope").configure()
		end,
	},
	{ "HiPhish/nvim-ts-rainbow2",   lazy = true },
	{ "nvim-treesitter/playground", lazy = true },
	{
		"nvim-treesitter/nvim-treesitter",
		event = "User FileOpened",
		cmd = {
			"TSInstall",
			"TSUninstall",
			"TSUpdate",
			"TSUpdateSync",
			"TSInstallInfo",
			"TSInstallSync",
			"TSInstallFromGrammar",
		},
		config = function()
			require("core.plugins.treesitter").configure()
		end,
	},
	{ "f-person/git-blame.nvim" },
	{
		"sindrets/diffview.nvim",
		requires = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.plugins.diffview").configure()
		end,
	},
	{
		"lewis6991/gitsigns.nvim",
		event = "User FileOpened",
		cmd = { "Gitsigns" },
		config = function()
			require("core.plugins.gitsigns").configure()
		end,
	},
	{
		"akinsho/bufferline.nvim",
		branch = "main",
		event = "User FileOpened",
		config = function()
			require("core.plugins.bufferline").configure()
		end,
	},
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("core.plugins.toggleterm").configure()
		end,
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("core.plugins.autopairs").configure()
		end,
		dependencies = { "nvim-treesitter/nvim-treesitter", "hrsh7th/nvim-cmp" },
	},
	{
		"Pocco81/auto-save.nvim",
		config = function()
			require("auto-save").setup()
		end,
	},
	{
		"ethanholz/nvim-lastplace",
		config = function()
			require("nvim-lastplace").setup({})
		end,
	},
	{
		"numToStr/Comment.nvim",
		config = function()
			require("core.plugins.comment").configure()
		end,
		keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
		event = "User FileOpened",
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		config = function()
			require("core.plugins.indent-blankline").configure()
		end,
		event = "User FileOpened",
	},
	{
		"phaazon/hop.nvim",
		config = function()
			require("hop").setup({})
		end,
	},
	{
		"abecodes/tabout.nvim",
		config = function()
			require("tabout").setup({})
		end,
	},
	{
		"brenoprata10/nvim-highlight-colors",
		config = function()
			require("nvim-highlight-colors").setup({
				render = "foreground",
			})
		end,
	},
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end,
	},
}
