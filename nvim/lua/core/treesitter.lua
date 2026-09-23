local M = {}

M.configure = function()
	local configs = require("nvim-treesitter.configs")

	-- Windows: compile parsers with zig cc (no MSVC / gcc needed)
	if vim.fn.has("win32") == 1 then
		require("nvim-treesitter.install").compilers = { "zig" }
	end

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
			"gdscript",
			"gdshader",
			"godot_resource",
		},
		ignore_install = {},
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
	})

	-- nvim-treesitter master's markdown queries predate nvim 0.12's node API:
	-- their `set-lang-from-info-string!` directive crashes the native highlighter
	-- (treesitter.lua get_range). Load the queries bundled with nvim instead,
	-- until the migration to nvim-treesitter's main branch.
	for _, ft in ipairs({ "markdown", "markdown_inline" }) do
		for _, kind in ipairs({ "highlights", "injections" }) do
			local path = vim.fs.joinpath(vim.env.VIMRUNTIME, "queries", ft, kind .. ".scm")
			if vim.fn.filereadable(path) == 1 then
				vim.treesitter.query.set(ft, kind, table.concat(vim.fn.readfile(path), "\n"))
			end
		end
	end

	local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
	parser_config.haxe = {
		install_info = {
			url = "https://github.com/fluctlight-kayaba/haxe-tree-sitter",
			files = { "src/parser.c", "src/scanner.c" },
			branch = "main",
			generate_requires_npm = false,
			requires_generate_from_grammar = false,
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
