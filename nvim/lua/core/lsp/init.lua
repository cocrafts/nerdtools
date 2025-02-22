local builtin = require("telescope.builtin")
local config = require("utils.config")
local helper = require("utils.helper")
local icons = require("utils.icons")

local M = {}
local hints = {
	inlay_hints = {
		parameter_hints = {
			show = true,
			prefix = string.format(" %s ", icons.kind.Number),
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

M.configure = function()
	local lsp = require("lsp-zero").preset({})
	local lspconfig = require("lspconfig")

	require("neodev").setup()

	if config.use_live_diagnostic then
		vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
			update_in_insert = true,
		})
	end

	lsp.on_attach(function(_, bufnr)
		local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
		local mapkey = function(mode, key, desc, cb)
			vim.keymap.set(mode, key, cb, {
				desc = desc,
				buffer = bufnr,
				remap = false,
			})
		end

		if filetype == "rust" then
			vim.cmd("set autoindent tabstop=2 shiftwidth=2")
		elseif filetype == "json" then
			vim.cmd("set expandtab shiftwidth=2")
		end

		mapkey("n", "K", "Preview signature", function()
			local winid = require("ufo").peekFoldedLinesUnderCursor()
			if not winid then
				vim.lsp.buf.hover()
			end
		end)

		mapkey("n", "gd", "Goto definition", function()
			helper.open_lsp_definitions()
		end)

		mapkey("n", "gD", "Goto implementations", function()
			builtin.lsp_implementations(helper.layouts.full_cursor())
		end)

		mapkey("n", "gs", "Incoming calls", function()
			vim.lsp.buf.incoming_calls()
		end)

		mapkey("n", "gS", "Outgoing calls", function()
			vim.lsp.buf.outgoing_calls()
		end)

		mapkey("n", "[d", "Previous diagnostic", function()
			vim.diagnostic.goto_prev()
		end)

		mapkey("n", "]d", "Next diagnostic", function()
			vim.diagnostic.goto_next()
		end)
	end)

	lsp.setup()

	require("core.lsp.terraform").configure(lspconfig)
	require("core.lsp.eslint").configure(lspconfig)
	require("core.lsp.typescript-tools").configure()
	require("core.lsp.terminal").configureBash(lspconfig)
	require("core.lsp.terminal").configureNushell(lspconfig)
	require("core.lsp.cmake").configure(lspconfig)
	require("core.lsp.html").configure(lspconfig)
	require("core.lsp.json").configure(lspconfig)
	require("core.lsp.graphql").configure(lspconfig)
	require("core.lsp.null-ls").configure()

	if config.use_snyk then
		require("core.lsp.snyk").configure(lspconfig)
	end

	if config.use_haxe then
		require("core.lsp.haxe").configure(lspconfig)
	end

	if config.use_ruby then
		require("core.lsp.ruby-lsp").configure(lspconfig)
	end

	if config.use_lua then
		require("core.lsp.lua-ls").configure(lspconfig)
	end

	if config.use_python then
		require("core.lsp.python").configure(lspconfig)
	end

	if config.use_rust then
		require("core.lsp.toml").configure(lspconfig)
		require("core.lsp.rust").configure()
	end

	if config.use_swift then
		require("core.lsp.swift").configure(lspconfig)
	end

	if config.use_zig then
		require("core.lsp.zls").configure(lspconfig)
	end

	if config.use_nim then
		require("core.lsp.nim").configure(lspconfig)
	end

	if config.use_gleam then
		require("core.lsp.gleam").configure(lspconfig)
	end

	if config.use_odin then
		require("core.lsp.odin").configure(lspconfig)
	end

	if config.use_clang then
		require("core.lsp.clang").configure(lspconfig)
		require("core.lsp.meson").configure(lspconfig)
	end

	if config.use_csharp then
		require("core.lsp.csharp").configure(lspconfig)
	end

	if config.use_go then
		require("core.lsp.go").configure(lspconfig)
	end

	if config.use_sql then
		require("core.lsp.sql").configure(lspconfig)
	end

	if config.use_wgsl then
		require("core.lsp.wgsl").configure(lspconfig)
	end
end

return M
