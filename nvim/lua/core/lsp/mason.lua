local config = require("utils.config")
local M = {}

local ensure_installed = {
	"graphql",
	"tailwindcss",
}

M.configure = function()
	if vim.loop.os_uname().sysname == "Darwin" then
		require("mason").setup({
			registries = {
				"github:mason-org/mason-registry", -- install with MasonInstall roslyn
				"github:Crashdummyy/mason-registry",
			},
		})

		if config.use_svelte then
			table.insert(ensure_installed, "svelte")
		end

		if config.use_python then
			table.insert(ensure_installed, "pyright")
		end

		if config.use_clang then
			table.insert(ensure_installed, "mesonlsp")
		end

		if config.use_elixir then
			table.insert(ensure_installed, "elixirls")
		end

		require("mason-lspconfig").setup({
			automatic_enable = true,
			ensure_installed = ensure_installed,
		})
	end
end

return M
