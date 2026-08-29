local config = require("utils.config")
local M = {}

local ensure_installed = {
	"graphql",
	"tailwindcss",
}

M.configure = function()
	local sysname = vim.loop.os_uname().sysname
	-- macOS and Windows get LSP servers auto-installed through Mason (on
	-- Windows they need node from mise as the runtime for the npm-based ones).
	-- Linux stays opted out for now.
	if sysname == "Darwin" or sysname == "Windows_NT" then
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
			ensure_installed = ensure_installed,
			handlers = {
				-- Default handler
				function(server_name)
					require("lspconfig")[server_name].setup({})
				end,
			},
		})
	end
end

return M
