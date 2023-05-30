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
			{ "jose-elias-alvarez/typescript.nvim" },
			{ "simrat39/rust-tools.nvim" },
			{ "simrat39/inlay-hints.nvim" },
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
			require("core.plugins.lualine").configure()
		end
	},
	{ "folke/lazy.nvim",       tag = "stable" },
	{ "folke/neodev.nvim",     lazy = true },
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
	{ "nvim-telescope/telescope-fzf-native.nvim", build = "make", lazy = true },
	{ "nvim-lua/plenary.nvim",                    lazy = true },
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = { "telescope-fzf-native.nvim" },
		lazy = true,
		config = function()
			require("core.plugins.telescope").configure()
		end,
	},
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
}