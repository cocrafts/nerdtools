local M = {}

local hints = {
	inlay_hints = {
		parameter_hints = {
			show = true,
			prefix = " <- ",
			separator = ", ",
			remove_colon_start = false,
			remove_colon_end = true,
		},
		type_hints = {
			-- type and other hints
			show = true,
			prefix = " ",
			separator = ", ",
			remove_colon_start = false,
			remove_colon_end = false,
		},
		only_current_line = false,
		-- separator between types and parameter hints. Note that type hints are
		-- shown before parameter
		labels_separator = "  ",
		-- whether to align to the length of the longest line in the file
		max_len_align = false,
		-- padding from the left if max_len_align is true
		max_len_align_padding = 1,
		-- highlight group
		highlight = "LspInlayHint",
		-- virt_text priority
		priority = 0,
	},
	enabled_at_startup = true,
	debug_mode = false,
}

local fidgets = {
	text = {
		done = "",
	},
}

M.configure = function()
	local lsp = require("lsp-zero").preset({})
	local lspconfig = require("lspconfig")

	require("lsp-inlayhints").setup(hints)

	lsp.ensure_installed({
		"eslint",
		"graphql",
		"tsserver",
		"rust_analyzer",
	})

	lsp.on_attach(function(_, bufnr)
		local key = require("utils.key")
		local opts = { buffer = bufnr, remap = false }

		lsp.default_keymaps({ buffer = bufnr })
		vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
		vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
		vim.keymap.set("n", "[d", function() vim.diagnostic.goto_prev() end, opts)
		vim.keymap.set("n", "]d", function() vim.diagnostic.goto_next() end, opts)
		vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
		vim.keymap.set("n", "<leader>vs", function() vim.lsp.buf.workspace_symbol() end, opts)
		vim.keymap.set("n", "<leader>va", function() vim.lsp.buf.code_action() end, opts)
		vim.keymap.set("n", "<leader>vr", function() vim.lsp.buf.rename() end, opts)
		vim.keymap.set("n", "<leader>ve", function() vim.lsp.buf.references() end, opts)
		vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
	end)

	lsp.setup()

	require("core.lsp.rust").configure()
	require("core.lsp.tsserver").configure(lspconfig)
	require("core.lsp.graphql").configure(lspconfig)
	require("fidget").setup(fidgets)
end

return M
