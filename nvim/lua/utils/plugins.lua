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
				end
			},
			{ "lvimuser/lsp-inlayhints.nvim" },
			{ "hrsh7th/nvim-cmp" }, -- Autocompletion
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "hrsh7th/cmp-cmdline" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "L3MON4D3/LuaSnip" },
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
		end
	},
	{
		"nvim-tree/nvim-tree.lua",
		requires = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.plugins.nvim-tree").configure()
		end
	},
	{
		"nvim-lualine/lualine.nvim",
		event = "VimEnter",
		config = function()
			require("core.lualine").configure()
		end
	},
	{ "folke/lazy.nvim",       tag = "stable" },
	{
		"folke/which-key.nvim",
		config = function()
			require("core.plugins.whichkey").configure()
		end
	},
	{
		"folke/tokyonight.nvim",
		config = function()
			require("core.plugins.tokyonight").configure()
		end
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
		end
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
}
