local M = {}

M.configure = function()
	vim.lsp.config("lua_ls", {
		settings = {
			Lua = {
				hint = { enable = true },
			},
		},
		on_init = function(client)
			local folder = client.workspace_folders and client.workspace_folders[1]
			local path = folder and folder.name
			if not path or (not vim.uv.fs_stat(path .. "/.luarc.json") and not vim.uv.fs_stat(path .. "/.luarc.jsonc")) then
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
				})

				client:notify("workspace/didChangeConfiguration", { settings = client.config.settings })
			end

			return true
		end,
	})
		vim.lsp.enable("lua_ls")
end

return M
