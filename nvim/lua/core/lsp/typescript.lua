local M = {}

M.configure = function()
	local typescript = require("typescript")

	typescript.setup({
		disable_commands = true,
		go_to_source_definition = {
			fallback = true, -- fall back to standard LSP definition on failure
		},
		server = {
			on_attach = function(client, bufnr)
				vim.lsp.buf.inlay_hint(bufnr, true)
				vim.keymap.set("n", "<leader>vi", "<cmd>TypescriptAddMissingImports<CR>", { buffer = bufnr })
			end,
			settings = {
				javascript = {
					inlayHints = {
						includeInlayEnumMemberValueHints = true,
						includeInlayFunctionLikeReturnTypeHints = true,
						includeInlayFunctionParameterTypeHints = true,
						includeInlayParameterNameHints = "all", -- 'none' | 'literals' | 'all';
						includeInlayParameterNameHintsWhenArgumentMatchesName = true,
						includeInlayPropertyDeclarationTypeHints = true,
						includeInlayVariableTypeHints = true,
					},
				},
				typescript = {
					inlayHints = {
						includeInlayEnumMemberValueHints = true,
						includeInlayFunctionLikeReturnTypeHints = true,
						includeInlayFunctionParameterTypeHints = true,
						includeInlayParameterNameHints = "all", -- 'none' | 'literals' | 'all';
						includeInlayParameterNameHintsWhenArgumentMatchesName = true,
						includeInlayPropertyDeclarationTypeHints = true,
						includeInlayVariableTypeHints = true,
					},
				},
			},
		},
	})
end

return M
