local config = require("utils.config")
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

	require("neodev").setup()

	if config.use_inlay_hints then
		require("lsp-inlayhints").setup(hints)
	end

	if config.use_live_diagnostic then
		vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
			update_in_insert = true,
		})
	end

	lsp.on_attach(function(_, bufnr)
		local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

		lsp.default_keymaps({ buffer = bufnr })
		vim.keymap.set("n", "K", function()
			vim.lsp.buf.hover()
		end, get_opts(bufnr, "Preview signature"))
		vim.keymap.set("n", "gd", function()
			vim.lsp.buf.definition()
		end, get_opts(bufnr, "Goto definition"))
		vim.keymap.set("n", "gD", function()
			vim.lsp.buf.implementation()
		end, get_opts(bufnr, "Goto definition"))
		vim.keymap.set("n", "gs", function()
			vim.lsp.buf.incoming_calls()
		end, get_opts(bufnr, "Incoming calls"))
		vim.keymap.set("n", "gS", function()
			vim.lsp.buf.outgoing_calls()
		end, get_opts(bufnr, "Outgoing calls"))
		vim.keymap.set("n", "[d", function()
			vim.diagnostic.goto_prev()
		end, get_opts(bufnr, "Previous diagnostic"))
		vim.keymap.set("n", "]d", function()
			vim.diagnostic.goto_next()
		end, get_opts(bufnr, "Next diagnostic"))

		if filetype == "rust" then
			vim.cmd("set autoindent tabstop=2 shiftwidth=2")
		elseif filetype == "json" then
			vim.cmd("set expandtab shiftwidth=2")
		end
	end)

	lsp.setup()

	if config.use_null_ls then
		require("core.lsp.null-ls").configure()
	else
		require("core.lsp.efm").configure(lspconfig)
	end

	require("core.lsp.typescript-tools").configure()
	require("core.lsp.rust").configure()
	require("core.lsp.toml").configure(lspconfig)
	require("core.lsp.go").configure(lspconfig)
	require("core.lsp.bash").configure(lspconfig)
	require("core.lsp.clang").configure(lspconfig)
	require("core.lsp.cmake").configure(lspconfig)
	require("core.lsp.csharp").configure(lspconfig)
	require("core.lsp.zls").configure(lspconfig)
	require("core.lsp.html").configure(lspconfig)
	require("core.lsp.json").configure(lspconfig)
	require("core.lsp.graphql").configure(lspconfig)
	require("core.lsp.lua-ls").configure(lspconfig)
end

return M
