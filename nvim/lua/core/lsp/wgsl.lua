local M = {}

M.configure = function(lspconfig)
	vim.filetype.add({ extension = { wgsl = "wgsl" } })

	local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
	parser_config.wgsl = {
		install_info = {
			url = "https://github.com/szebniok/tree-sitter-wgsl",
			files = { "src/parser.c" },
		},
	}

	require("nvim-treesitter.configs").setup({
		ensure_installed = { "wgsl" },
		highlight = {
			enable = true,
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "gnn",
				node_incremental = "grn",
				scope_incremental = "grc",
				node_decremental = "grm",
			},
		},
	})

	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = "nvim_treesitter#foldexpr()"

	lspconfig.wgsl_analyzer.setup({})
end

return M
