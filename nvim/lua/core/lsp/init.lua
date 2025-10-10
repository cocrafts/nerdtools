local fzf = require("fzf-lua")
local config = require("utils.config")
local helper = require("utils.helper")

local M = {}

M.configure = function()
	local lsp = require("lsp-zero")
	local lspconfig = require("lspconfig")

	require("neodev").setup()

	if config.use_live_diagnostic then
		vim.diagnostic.config({
			update_in_insert = true,
		})
	end

	lsp.on_attach(function(client, bufnr)
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
			fzf.lsp_implementations()
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
	require("core.lsp.toml").configure(lspconfig)
	require("core.lsp.graphql").configure(lspconfig)
	require("core.lsp.none-ls").configure()
	require("core.lsp.nim").configure(lspconfig)
	require("core.lsp.zls").configure(lspconfig)
	require("core.lsp.sql").configure(lspconfig)
	-- require("core.lsp.wgsl").configure(lspconfig)
	require("core.lsp.odin").configure(lspconfig)
	require("core.lsp.swift").configure(lspconfig)
	require("core.lsp.rust").configure()
	require("core.lsp.ruby-lsp").configure(lspconfig)
	require("core.lsp.haxe").configure(lspconfig)

	if config.use_svelte then
		vim.lsp.enable("svelte") -- svelte does not require its own lspconfig
	end

	if config.use_lua then
		require("core.lsp.lua-ls").configure(lspconfig)
	end

	if config.use_python then
		require("core.lsp.python").configure(lspconfig)
	end

	if config.use_gleam then
		require("core.lsp.gleam").configure(lspconfig)
	end

	if config.use_elixir then
		require("core.lsp.elixir-tools").configure()
	end

	if config.use_clang then
		require("core.lsp.clang").configure(lspconfig)
		require("core.lsp.meson").configure(lspconfig)
	end

	if config.use_go then
		require("core.lsp.go").configure(lspconfig)
	end

	if config.use_godot then
		require("core.lsp.godot").configure(lspconfig)
	end
end

return M
