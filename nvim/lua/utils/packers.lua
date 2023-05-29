return {
	{ "wbthomason/packer.nvim" },
	{
		"nvim-tree/nvim-tree.lua",
		requires = { 'nvim-tree/nvim-web-devicons' },
		config = function()
			require("core.plugins.nvim-tree").configure()
		end
	},
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			require("core.plugins.lualine").configure()
		end
	},
	{ "folke/lazy.nvim",       tag = "stable" },
	{
		"folke/which-key.nvim",
		lazy = true,
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
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		run = "make",
	},
	{
		'nvim-telescope/telescope.nvim',
		requires = { { 'nvim-lua/plenary.nvim' } },
		tag = '0.1.1',
	},
	{
		"nvim-treesitter/nvim-treesitter",
		config = function()
			require("core.plugins.treesitter").configure()
		end
	},
}
