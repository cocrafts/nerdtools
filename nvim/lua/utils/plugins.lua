return {
	{ "folke/tokyonight.nvim", lazy = true },
	{ "lukas-reineke/onedark.nvim", lazy = true },
	{ "catppuccin/nvim", lazy = true },
	{
		"nmac427/guess-indent.nvim",
		event = { "BufReadPre", "BufNewFile" },
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
		ft = { "markdown" },
		config = function()
			require("core.markdown").configureRenderMarkdown()
		end,
	},
	{
		"christoomey/vim-tmux-navigator",
		lazy = false, -- Load immediately so keymaps work
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
			"TmuxNavigatorProcessList",
		},
		config = function()
			-- Resolve the nerdtools checkout from this config's real location so the
			-- path works whether ~/.config/nvim is a symlink, a junction, or the repo
			-- itself, and regardless of what the checkout directory is named.
			local config = vim.fn.stdpath("config")
			local root = vim.uv.fs_realpath(config) or config
			local plugin = vim.fs.joinpath(vim.fs.dirname(root), "conf/herdr/vim-herdr-navigation/editor/nvim.lua")
			if vim.uv.fs_stat(plugin) then
				dofile(plugin)
			else
				vim.notify("vim-herdr-navigation not found at " .. plugin, vim.log.levels.WARN)
			end
		end,
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
		dependencies = {
			{ "nvimtools/none-ls.nvim" },
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
			{ "nanotee/sqls.nvim", lazy = true },
			{ "mrcjkb/rustaceanvim", version = "^6" },
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
				ft = "hurl",
				dependencies = {
					"MunifTanjim/nui.nvim",
					"nvim-lua/plenary.nvim",
					"nvim-treesitter/nvim-treesitter",
				},
				config = function()
					require("core.hurl").configure()
				end,
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
				event = "BufRead Cargo.toml",
				dependencies = { "nvim-lua/plenary.nvim" },
				config = function()
					require("crates").setup()
				end,
			},
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
	{ "echasnovski/mini.icons", lazy = true },
	{ "lbrayner/vim-rzip" },
	{ "jparise/vim-graphql", ft = "graphql" },
	{ "alaviss/nim.nvim", ft = "nim" },
	{ "tact-lang/tact.vim", ft = "tact" },
	{ "yuezk/vim-js", ft = { "javascript", "javascriptreact" } },
	{ "HerringtonDarkholme/yats.vim", ft = { "typescript", "typescriptreact" } },
	{ "maxmellon/vim-jsx-pretty", ft = { "javascriptreact", "typescriptreact" } },
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
		event = "User FileOpened",
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
	{ "folke/lazy.nvim", tag = "stable" },
	{
		"metascriptlang/metascript.nvim",
		event = "VeryLazy",
		ft = "metascript",
	},
	{ "folke/lazydev.nvim", ft = "lua", opts = {} },
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
		event = "BufRead package.json",
		dependencies = { "MunifTanjim/nui.nvim" },
		config = function()
			require("core.package-info").configure()
		end,
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		config = function()
			require("core.whichkey").configure()
		end,
	},
	{ "nvim-lua/plenary.nvim", lazy = true },
	{
		"nvim-telescope/telescope.nvim",
		cmd = "Telescope",
		init = function()
			---@diagnostic disable-next-line: duplicate-set-field
			vim.ui.select = function(...)
				require("lazy").load({ plugins = { "telescope.nvim" } })
				return vim.ui.select(...)
			end
		end,
		dependencies = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-tree/nvim-web-devicons" },
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = vim.fn.has("win32") == 1
						and "cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build"
					or "make",
			},
			{ "nvim-telescope/telescope-live-grep-args.nvim" },
			{ "smartpde/telescope-recent-files" },
			{ "nvim-telescope/telescope-ui-select.nvim" },
		},
		config = function()
			require("core.telescope").configure()
		end,
	},
	{
		"sudormrfbin/cheatsheet.nvim",
		dependencies = {
			"nvim-lua/popup.nvim",
			"nvim-lua/plenary.nvim",
		},
		cmd = "Cheatsheet",
	},
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master", -- config uses the master API (require("nvim-treesitter.configs")); `main` is the incompatible rewrite
		build = ":TSUpdate",
		event = "User FileOpened",
		config = function()
			require("core.treesitter").configure()
		end,
	},
	{
		"sindrets/diffview.nvim",
		cmd = {
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewFileHistory",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("core.diff").configureDiffview()
		end,
	},
	{
		"fluctlight-kayaba/meister.nvim",
		dependencies = { "nickjvandyke/opencode.nvim", "sindrets/diffview.nvim" },
		event = "BufReadPost",
		cmd = "Meister",
		keys = {
			{
				"<leader>ma",
				"<Plug>(meister-annotate)",
				mode = { "n", "x" },
				desc = "Meister: annotate",
			},
			{ "<leader>ms", "<Plug>(meister-send-all)", desc = "Meister: send all annotations" },
			{ "<leader>mS", "<Plug>(meister-send-file)", desc = "Meister: send current file" },
			{ "<leader>mr", "<Plug>(meister-run-file)", desc = "Meister: send + run current file" },
			{ "<leader>mR", "<Plug>(meister-run-all)", desc = "Meister: send + run all annotations" },
			{ "<leader>mf", "<Plug>(meister-list)", desc = "Meister: list annotations" },
			{ "<leader>mc", "<Plug>(meister-clear)", desc = "Meister: clear annotations" },
			{ "<leader>mp", "<Plug>(meister-pick-session)", desc = "Meister: pick session (project)" },
			{ "<leader>mP", "<Plug>(meister-pick-session-all)", desc = "Meister: pick session (all)" },
		},
		opts = {},
	},
	{
		"lewis6991/gitsigns.nvim",
		event = "User FileOpened",
		cmd = { "Gitsigns" },
		config = function()
			require("core.gitsigns").configure()
		end,
	},
	{ "f-person/git-blame.nvim", event = "User FileOpened" },
	{
		"FabijanZulj/blame.nvim",
		cmd = "BlameToggle",
		config = function()
			require("core.diff").configureBlame()
		end,
	},
	{
		"lewis6991/satellite.nvim",
		event = "User FileOpened",
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
		cmd = { "ToggleTerm", "TermExec", "ToggleTermToggleAll", "TermSelect" },
		keys = { { [[<c-\>]], mode = "i" } },
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
	{ "windwp/nvim-ts-autotag", event = "User FileOpened" },
	-- { "wakatime/vim-wakatime" },
	{
		"ethanholz/nvim-lastplace",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("core.lastplace").configure()
		end,
	},
	{ "JoosepAlviste/nvim-ts-context-commentstring", lazy = true },
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
		event = "User FileOpened",
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
		event = "User FileOpened",
		config = function()
			require("core.illuminate").configure()
		end,
	},
	{
		-- highlight/preview color code
		"brenoprata10/nvim-highlight-colors",
		event = "User FileOpened",
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
	{
		"bngarren/checkmate.nvim",
		ft = "markdown", -- Lazy loads for Markdown files matching patterns in 'files'
		config = function()
			require("core.markdown").configureCheckmate()
		end,
	},
	-- {
	-- 	"sphamba/smear-cursor.nvim",
	-- 	opts = {
	-- 		cursor_color = "none",
	-- 		stiffness = 0.3,
	-- 		trailing_stiffness = 0.1,
	-- 		damping = 0.5,
	-- 		trailing_exponent = 5,
	-- 		never_draw_over_target = true,
	-- 		hide_target_hack = true,
	-- 		gamma = 1,
	-- 		time_interval = 3,
	-- 	},
	-- },
}
