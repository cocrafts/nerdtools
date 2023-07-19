local M = {}

M.configure = function(lspconfig)
	local default_workspace = {
		library = {
			vim.fn.expand("$VIMRUNTIME"),
			require("neodev.config").types(),
			"${3rd}/busted/library",
			"${3rd}/luassert/library",
			"${3rd}/luv/library",
		},

		maxPreload = 5000,
		preloadFileSize = 10000,
	}

	lspconfig.lua_ls.setup({
		Lua = {
			telemetry = { enable = false },
			runtime = {
				version = "LuaJIT",
				special = {
					reload = "require",
				},
			},
		},
		dianogstics = {
			globals = { "vim", "reload" },
		},
		workspace = default_workspace,
	})
end

return M
