local M = {}

local options = {
	Lua = {
		-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
		runtime = "LuaJIT",
		special = {
			reload = "require",
		},
	},
	dianogstics = {
		-- Get the language server to recognize the `vim` global
		globals = { "vim", "reload", },
	},
	workspace = {
		-- Make the server aware of Neovim runtime files
		library = vim.api.nvim_get_runtime_file("", true),
	},
	-- Do not send telemetry data containing a randomized but unique identifier
	telemetry = {
		enable = false,
	},
}

M.configure = function(lspconfig)
	lspconfig.lua_ls.setup(options)
end

return M
