local M = {}

M.configure = function(lspconfig)
	lspconfig.lua_ls.setup({
		settings = {
			Lua = {
				hint = { enable = true },
			},
		},
		on_init = function(client)
			local path = client.workspace_folders[1].name
			if not vim.loop.fs_stat(path .. "/.luarc.json") and not vim.loop.fs_stat(path .. "/.luarc.jsonc") then
				client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
					Lua = {
						diagnostics = {
							enable = false,
						},
						format = {
							enable = true,
						},
						runtime = {
							version = "LuaJIT",
						},
					},
					workspace = {
						library = {
							vim.fn.expand("$VIMRUNTIME"),
							require("neodev.config").types(),
						},
						maxPreload = 5000,
						preloadFileSize = 10000,
						checkThirdParty = false,
					},
				})

				client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
			end

			return true
		end,
	})
end

return M
