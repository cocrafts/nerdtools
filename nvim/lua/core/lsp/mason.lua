local config = require("utils.config")
local M = {}

local ensure_installed = {
	"graphql",
	"efm",
	"stylelint_lsp",
	"jsonls",
	"html",
	"cssls",
}

M.configure = function()
	if vim.loop.os_uname().sysname == "Darwin" then
		require("mason").setup()

		if config.use_snyk then
			table.insert(ensure_installed, "snyk_ls")
		end

		if config.use_ruby then
			table.insert(ensure_installed, "ruby_ls")
		end

		if config.use_lua then
			table.insert(ensure_installed, "lua_ls")
		end

		if config.use_python then
			table.insert(ensure_installed, "pyright")
		end

		if config.use_rust then
			table.insert(ensure_installed, "rust_analyzer")
		end

		if config.use_zig then
			table.insert(ensure_installed, "zls")
		end

		if config.use_csharp then
			table.insert(ensure_installed, "omnisharp")
		end

		if config.use_go then
			table.insert(ensure_installed, "gopls")
		end

		require("mason-lspconfig").setup({
			ensure_installed = ensure_installed,
		})
	end
end

return M
