local config = require("utils.config")
local M = {}

local automatic_installation = {
	"graphql-language-service-cli",
	"stylelint-lsp",
	"json-lsp",
	"html-lsp",
	"css-lsp",
}

M.configure = function()
	if vim.loop.os_uname().sysname == "Darwin" then
		require("mason").setup()

		if config.use_snyk then
			table.insert(automatic_installation, "snyk-ls")
		end

		if config.use_ruby then
			table.insert(automatic_installation, "ruby-lsp")
		end

		if config.use_python then
			table.insert(automatic_installation, "pyright")
		end

		if config.use_clang then
			table.insert(automatic_installation, "mesonlsp")
		end

		if config.use_csharp then
			table.insert(automatic_installation, "omnisharp")
		end

		if config.use_elixir then
			table.insert(automatic_installation, "elixir-ls")
		end

		require("mason-lspconfig").setup({
			automatic_installation = automatic_installation,
		})
	end
end

return M
