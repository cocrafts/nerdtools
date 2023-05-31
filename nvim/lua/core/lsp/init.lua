local M = {}

local hint_opts = {
	renderer = "inlay-hints/render/eol",
	hints = {
		parameter = {
			show = true,
			highlight = "Comment",
		},
		type = {
			show = true,
			highlight = "Comment",
		}
	},
	eol = {
		right_align = false,   -- whether to align to the extreme right or not
		right_align_padding = 7, -- padding from the right if right_align is true
		parameter = {
			separator = ", ",
			format = function(hints)
				return string.format(" <- (%s)", hints)
			end,
		},
		type = {
			separator = ", ",
			format = function(hints)
				return string.format(" » (%s)", hints)
			end,
		},
	},
}

local fidget_opts = {
	text = {
		done = "",
	},
}

M.configure = function()
	local lsp = require("lsp-zero").preset({})
	local lspconfig = require("lspconfig")
	local hints = require("inlay-hints")

	hints.setup(hint_opts)

	lsp.ensure_installed({
		"eslint",
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

	lsp.skip_server_setup({ "rust_analyzer" })
	lsp.skip_server_setup({ "tsserver" })
	lsp.setup()

	require("core.lsp.rust").configure(hints)
	require("core.lsp.typescript").configure(hints)
	require("fidget").setup(fidget_opts)
end

return M
