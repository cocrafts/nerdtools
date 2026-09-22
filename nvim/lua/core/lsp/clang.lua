local M = {}

M.configure = function()
	vim.lsp.config("clangd", {
		settings = {
			clangd = {
				InlayHints = {
					Designators = true,
					Enabled = true,
					ParameterNames = true,
					DeducedTypes = true,
				},
				fallbackFlags = { "-std=c++20" },
			},
		}
	})
		vim.lsp.enable("clangd")
end

return M
