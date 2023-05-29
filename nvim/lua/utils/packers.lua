return {
	{ "wbthomason/packer.nvim" },
	{ "nvim-treesitter/nvim-treesitter" },
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
	{
		"folke/which-key.nvim",
		config = function()
			require("core.plugins.whichkey").configure()
		end
	},
	{
		'nvim-telescope/telescope.nvim',
		require = { { 'nvim-lua/plenary.nvim' } },
		tag = '0.1.0',
	}
}
