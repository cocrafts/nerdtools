local M = {}
local icons = require("utils.icons")

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
		done = icons.kind.Module,
	},
	fmt = {
		fidget = function(name, spinner)
			return string.format("%s %s ", spinner, name)
		end,
		task = function(name, message, percent)
			return string.format(
				"%s • %s%s ",
				name,
				message,
				percent and string.format(" (%s%%)", percent) or ""
			)
		end,
	},
}

local get_opts = function(bufnr, desc)
	return {
		desc = desc,
		buffer = bufnr,
		remap = false,
	}
end

M.configure = function()
	local lsp = require("lsp-zero").preset({})
	local lspconfig = require("lspconfig")

	require("lsp-inlayhints").setup(hints)
	require("neodev").setup({})

	lsp.ensure_installed({
		"eslint",
		"graphql",
		"tsserver",
		"lua_ls",
		"rust_analyzer",
	})

	lsp.on_attach(function(_, bufnr)
		local opts = { buffer = bufnr, remap = false }

		require("lsp_signature").on_attach({}, bufnr)

		lsp.default_keymaps({ buffer = bufnr })
		vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, get_opts(bufnr, "Preview signature"))
		vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, get_opts(bufnr, "Goto definition"))
		vim.keymap.set("n", "gD", function() vim.lsp.buf.implementation() end, get_opts(bufnr, "Goto definition"))
		vim.keymap.set("n", "gs", function() vim.lsp.buf.incoming_calls() end, get_opts(bufnr, "Incoming calls"))
		vim.keymap.set("n", "gS", function() vim.lsp.buf.outgoing_calls() end, get_opts(bufnr, "Outgoing calls"))
		vim.keymap.set("n", "[d", function() vim.diagnostic.goto_prev() end, get_opts(bufnr, "Previous diagnostic"))
		vim.keymap.set("n", "]d", function() vim.diagnostic.goto_next() end, get_opts(bufnr, "Next diagnostic"))
		vim.keymap.set("n", "<leader>jd", function() vim.diagnostic.open_float() end, get_opts(bufnr, "Diagnostic"))
		---@diagnostic disable-next-line: missing-parameter
		vim.keymap.set("n", "<leader>js", function() vim.lsp.buf.workspace_symbol() end, get_opts(bufnr, "Workspace symbols"))
		vim.keymap.set("n", "<leader>ja", function() vim.lsp.buf.code_action() end, get_opts(bufnr, "Code action"))
		vim.keymap.set("n", "<leader>jr", function() vim.lsp.buf.rename() end, get_opts(bufnr, "Rename"))
		vim.keymap.set("n", "<leader>je", function() vim.lsp.buf.references() end, get_opts(bufnr, "References"))
		vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, get_opts(bufnr, "Signature help"))
		vim.keymap.set("i", "<C-l>", function() vim.lsp.buf.format() end, get_opts(bufnr, "Format code"))

		vim.cmd(":LspLensOn")
	end)

	lsp.setup()

	require("core.lsp.rust").configure()
	require("core.lsp.tsserver").configure(lspconfig)
	require("core.lsp.eslint").configure(lspconfig)
	require("core.lsp.graphql").configure(lspconfig)
	require("core.lsp.lua-ls").configure(lspconfig)
	require("fidget").setup(fidgets)
end

return M
