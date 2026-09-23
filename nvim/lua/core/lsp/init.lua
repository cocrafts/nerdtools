local config = require("utils.config")
local helper = require("utils.helper")

local M = {}

local on_attach = function(bufnr)
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
		if config.use_telescope then
			require("telescope.builtin").lsp_implementations()
		else
			require("fzf-lua").lsp_implementations()
		end
	end)

	mapkey("n", "gs", "Incoming calls", function()
		vim.lsp.buf.incoming_calls()
	end)

	mapkey("n", "gS", "Outgoing calls", function()
		vim.lsp.buf.outgoing_calls()
	end)

	mapkey("n", "[d", "Previous diagnostic", function()
		vim.diagnostic.jump({ count = -1, float = true })
	end)

	mapkey("n", "]d", "Next diagnostic", function()
		vim.diagnostic.jump({ count = 1, float = true })
	end)
end

M.configure = function()
	vim.diagnostic.config({ float = { border = "rounded" } })

	if config.use_live_diagnostic then
		vim.diagnostic.config({
			update_in_insert = true,
		})
	end

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("core_lsp_attach", { clear = true }),
		callback = function(args)
			on_attach(args.buf)
		end,
	})

	require("core.lsp.terraform").configure()
	require("core.lsp.eslint").configure()
	require("core.lsp.typescript-tools").configure()
	require("core.lsp.terminal").configureBash()
	require("core.lsp.terminal").configureNushell()
	require("core.lsp.cmake").configure()
	require("core.lsp.html").configure()
	require("core.lsp.json").configure()
	require("core.lsp.toml").configure()
	require("core.lsp.graphql").configure()
	require("core.lsp.none-ls").configure()
	require("core.lsp.nim").configure()
	require("core.lsp.zls").configure()
	require("core.lsp.sql").configure()
	require("core.lsp.odin").configure()
	require("core.lsp.swift").configure()
	require("core.lsp.rust").configure()
	require("core.lsp.ruby-lsp").configure()
	require("core.lsp.haxe").configure()
	require("core.lsp.metascript").configure()

	if config.use_svelte then
		vim.lsp.enable("svelte") -- svelte does not require its own lspconfig
	end

	if config.use_lua then
		require("core.lsp.lua-ls").configure()
	end

	if config.use_python then
		require("core.lsp.python").configure()
	end

	if config.use_gleam then
		require("core.lsp.gleam").configure()
	end

	if config.use_elixir then
		require("core.lsp.elixir-tools").configure()
	end

	if config.use_clang then
		require("core.lsp.clang").configure()
		require("core.lsp.meson").configure()
	end

	if config.use_go then
		require("core.lsp.go").configure()
	end

	if config.use_godot then
		require("core.lsp.godot").configure()
	end
end

return M
