local M = {}
local null = require("utils.null")

M.configure = function()
	local nls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local sources = {
		nls.builtins.formatting.stylua,
		-- nls.builtins.formatting.zigfmt,
		-- nls.builtins.formatting.rustfmt,
		nls.builtins.formatting.csharpier,
		nls.builtins.diagnostics.revive,
		nls.builtins.formatting.golines.with({
			extra_args = {
				"--max-len=180",
				"--base-formatter=gofumpt",
			},
		}),

		nls.builtins.formatting.eslint_d,
		nls.builtins.diagnostics.eslint_d,
		nls.builtins.diagnostics.typos,
		null.formatting.jq,

		nls.builtins.formatting.shfmt,
		nls.builtins.diagnostics.stylelint,
	}

	nls.setup({
		sources = sources,
		debounce = 1000,
		default_timeout = 5000,
		on_attach = function(client, bufnr)
			if client.supports_method("textDocument/formatting") then
				vim.api.nvim_clear_autocmds({
					group = augroup,
					buffer = bufnr,
				})

				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					callback = function()
						vim.lsp.buf.format({ bufnr = bufnr })
					end,
				})
			end
		end,
	})
end

return M
