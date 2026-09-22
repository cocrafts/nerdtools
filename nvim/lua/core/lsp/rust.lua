local M = {}

M.configure = function()
	vim.g.rustaceanvim = {
		tools = {
			hover_actions = {
				auto_focus = false,
			},
		},
		server = {
			on_attach = function(_, bufnr)
				vim.keymap.set("n", "<C-space>", function()
					vim.cmd.RustLsp({ "hover", "actions" })
				end, { buffer = bufnr })
				vim.keymap.set("n", "<leader>a", function()
					vim.cmd.RustLsp("codeAction")
				end, { buffer = bufnr })
			end,
		},
	}
end

return M
