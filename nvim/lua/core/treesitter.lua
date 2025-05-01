local M = {}

M.configure = function()
	local configs = require("nvim-treesitter.configs")

	configs.setup({
		on_config_done = nil,
		sync_install = false,
		auto_install = true,
		modules = {},
		ensure_installed = {
			"typescript",
			"tsx",
			"sql",
			"graphql",
			"rust",
			"zig",
			"gleam",
			"eex",
			"elixir",
			"heex",
			"surface",
			"lua",
			"vim",
			"gitignore",
			"toml",
			"json",
			"html",
			"hurl",
			"func",
			"tact",
			"markdown",
			"markdown_inline",
		},
		ignore_install = {},
		autotag = {
			enable = true,
		},
		highlight = { enabled = true },
		-- rainbow = { enable = true },
		indent = { enable = true },
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<c-space>",
				node_incremental = "<c-space>",
				scope_incremental = "<c-s>",
				node_decremental = "<M-space>",
			},
		},
		textobjects = {
			select = {
				enable = true,
				lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
				keymaps = {
					-- You can use the capture groups defined in textobjects.scm
					["aa"] = "@parameter.outer",
					["ia"] = "@parameter.inner",
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
				},
			},
			move = {
				enable = true,
				set_jumps = true, -- whether to set jumps in the jumplist
				goto_next_start = {
					["]m"] = "@function.outer",
					["]]"] = "@class.outer",
				},
				goto_next_end = {
					["]M"] = "@function.outer",
					["]["] = "@class.outer",
				},
				goto_previous_start = {
					["[m"] = "@function.outer",
					["[["] = "@class.outer",
				},
				goto_previous_end = {
					["[M"] = "@function.outer",
					["[]"] = "@class.outer",
				},
			},
			swap = {
				enable = true,
				swap_next = {
					["<leader>a"] = "@parameter.inner",
				},
				swap_previous = {
					["<leader>A"] = "@parameter.inner",
				},
			},
		},
		playground = {
			enable = false,
			disable = {},
			updatetime = 25,      -- Debounced time for highlighting nodes in the playground from source code
			persist_queries = false, -- Whether the query persists across vim sessions
			keybindings = {
				toggle_query_editor = "o",
				toggle_hl_groups = "i",
				toggle_injected_languages = "t",
				toggle_anonymous_nodes = "a",
				toggle_language_display = "I",
				focus_language = "f",
				unfocus_language = "F",
				update = "R",
				goto_node = "<cr>",
				show_help = "?",
			},
		},
	})

	local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
	parser_config.haxe = {
		install_info = {
			url = "https://github.com/vantreeseba/tree-sitter-haxe",
			files = { "src/parser.c", "src/scanner.c" },
			-- optional entries:
			branch = "main",
		},
		filetype = "haxe",
	}

	parser_config.d2 = {
		install_info = {
			url = "https://github.com/ravsii/tree-sitter-d2",
			files = { "src/parser.c" },
			branch = "main",
		},
		filetype = "d2",
	}
end

return M
