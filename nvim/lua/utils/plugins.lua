return {
	{ "folke/tokyonight.nvim" },
	{ "lukas-reineke/onedark.nvim" },
	{ "catppuccin/nvim" },
	{
		"nmac427/guess-indent.nvim",
		config = function()
			require("core.guess-indent").configure()
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = "cd app && yarn install",
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "Avante" },
		opts = {
			file_types = { "markdown", "Avante" },
		},
	},
	{
		"supermaven-inc/supermaven-nvim",
		config = function()
			require("core.supermaven").configure()
		end,
	},
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		lazy = false,
		version = false,
		build = "make",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"stevearc/dressing.nvim",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
			"echasnovski/mini.pick", -- for file_selector provider mini.pick
			"nvim-telescope/telescope.nvim",
			"hrsh7th/nvim-cmp",
			"ibhagwan/fzf-lua",
			{
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
					},
				},
			},
		},
	},
	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
		dependencies = {
			{ "neovim/nvim-lspconfig" },
			{ "nvimtools/none-ls.nvim" },
			{ "nvimdev/guard.nvim" },
			{
				"williamboman/mason.nvim",
				build = function()
					---@diagnostic disable-next-line: param-type-mismatch
					pcall(vim.cmd, "MasonUpdate")
				end,
			},
			{
				"williamboman/mason-lspconfig.nvim",
				config = function()
					require("core.lsp.mason").configure()
				end,
			},
			{
				"chrisgrieser/nvim-lsp-endhints",
				event = "LspAttach",
				opts = {}, -- required, even if empty
			},
			{
				"seblyng/roslyn.nvim",
				ft = "cs",
				---@module 'roslyn.config'
				---@type RoslynNvimConfig
				opts = {
					config = {
						broad_search = true,
						settings = {
							["csharp|symbol_search"] = {
								dotnet_search_reference_assemblies = true,
							},
							["csharp|formatting"] = {
								dotnet_organize_imports_on_format = true,
							},
							["csharp|inlay_hints"] = {
								csharp_enable_inlay_hints_for_implicit_object_creation = true,
								csharp_enable_inlay_hints_for_implicit_variable_types = true,
								csharp_enable_inlay_hints_for_lambda_parameter_types = true,
								csharp_enable_inlay_hints_for_types = true,
								dotnet_enable_inlay_hints_for_indexer_parameters = true,
								dotnet_enable_inlay_hints_for_literal_parameters = true,
								dotnet_enable_inlay_hints_for_object_creation_parameters = true,
								dotnet_enable_inlay_hints_for_other_parameters = true,
								dotnet_enable_inlay_hints_for_parameters = true,
								dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
								dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
								dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
							},
							["csharp|code_lens"] = {
								dotnet_enable_references_code_lens = true,
							},
						},
					},
				},
			},
			{ "nanotee/sqls.nvim" },
			{ "jparise/vim-graphql" },
			{ "alaviss/nim.nvim" },
			{ "tact-lang/tact.vim" },
			{ "simrat39/rust-tools.nvim" },
			{
				"elixir-tools/elixir-tools.nvim",
				dependencies = { "nvim-lua/plenary.nvim" },
				version = "*",
				event = { "BufReadPre", "BufNewFile" },
			},
			{
				"pmizio/typescript-tools.nvim",
				dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
			},
			{
				"jellydn/hurl.nvim",
				dependencies = {
					"MunifTanjim/nui.nvim",
					"nvim-lua/plenary.nvim",
					"nvim-treesitter/nvim-treesitter",
				},
				config = function()
					require("core.hurl").configure()
				end,
			},
			{ "yuezk/vim-js" },
			{ "HerringtonDarkholme/yats.vim" },
			{ "maxmellon/vim-jsx-pretty" },
			{ "lbrayner/vim-rzip" },
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
			{
				"MysticalDevil/inlay-hints.nvim",
				event = "LspAttach",
				dependencies = { "neovim/nvim-lspconfig" },
				config = function()
					require("inlay-hints").setup()
				end,
			},
			{
				"L3MON4D3/LuaSnip",
				dependencies = { "friendly-snippets" },
				build = "make install_jsregexp",
				event = "InsertEnter",
				config = function()
					require("core.luasnip").configure()
				end,
			},
			{
				"hrsh7th/nvim-cmp",
				config = function()
					require("core.lsp.cmp").configure()
				end,
			}, -- Autocompletion
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "hrsh7th/cmp-cmdline" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "rafamadriz/friendly-snippets", lazy = true },
		},
		config = function()
			require("core.lsp").configure()
		end,
	},
	{ "echasnovski/mini.icons" },
	{
		"miversen33/sunglasses.nvim",
		event = "UIEnter",
		config = function()
			require("sunglasses").setup({
				filter_percent = 0.1,
			})
		end,
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			{
				"nvim-tree/nvim-web-devicons",
				config = function()
					require("core.devicons").configure()
				end,
			},
		},
		branch = "v3.x",
		cmd = "Neotree",
		config = function()
			require("core.neo-tree").configure()
		end,
	},
	{
		"kevinhwang91/nvim-ufo",
		dependencies = { "kevinhwang91/promise-async" },
		config = function()
			require("core.fold").configure()
		end,
	},
	{
		"3rd/image.nvim",
		config = function()
			require("core.graphical").configureImage()
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
	{ "folke/twilight.nvim" },
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = { "MunifTanjim/nui.nvim" },
		config = function()
			require("core.noice").configure()
		end,
	},
	{
		"vuki656/package-info.nvim",
		dependencies = { "MunifTanjim/nui.nvim" },
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
	{ "nvim-telescope/telescope-fzf-native.nvim", lazy = true,      build = "make" },
	{ "nvim-lua/plenary.nvim",                    lazy = true },
	{ "kkharji/sqlite.lua",                       module = "sqlite" },
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
			{ "aaronhallaert/advanced-git-search.nvim" },
			{
				"sudormrfbin/cheatsheet.nvim",
				dependencies = {
					"nvim-telescope/telescope.nvim",
					"nvim-lua/popup.nvim",
					"nvim-lua/plenary.nvim",
				},
			},
			{
				"AckslD/nvim-neoclip.lua",
				dependencies = {
					"nvim-telescope/telescope.nvim",
					"kkharji/sqlite.lua",
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
	{
		"sindrets/diffview.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.diff").configureDiffview()
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
	{ "f-person/git-blame.nvim" },
	{
		"FabijanZulj/blame.nvim",
		lazy = false,
		config = function()
			require("core.diff").configureBlame()
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
			require("core.lastplace").configure()
		end,
	},
	{ "JoosepAlviste/nvim-ts-context-commentstring" },
	{
		"numToStr/Comment.nvim",
		config = function()
			require("core.comment").configure()
		end,
		keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
		event = "User FileOpened",
	},
	{
		"shellRaining/hlchunk.nvim",
		event = { "UIEnter" },
		config = function()
			require("core.hlchunk").configure()
		end,
	},
	{
		"HiPhish/rainbow-delimiters.nvim",
		config = function()
			require("core.rainbow").configure()
		end,
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
			require("core.highlight-colors").configure()
		end,
	},
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		config = function()
			require("core.surround").configure()
		end,
	},
}
