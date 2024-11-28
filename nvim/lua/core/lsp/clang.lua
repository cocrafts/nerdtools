local M = {}

M.configure = function(lspconfig)
	lspconfig.clangd.setup({
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
end

return M
