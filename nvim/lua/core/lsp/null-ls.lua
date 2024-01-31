local M = {}
local null = require("utils.null")

M.configure = function()
	local nls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local sources = {
		nls.builtins.formatting.clang_format, -- clang
		nls.builtins.diagnostics.clang_check,

		nls.builtins.formatting.stylua, -- lua
		nls.builtins.diagnostics.selene,

		nls.builtins.formatting.ruff_format, -- python
		nls.builtins.diagnostics.ruff,
		nls.builtins.diagnostics.mypy,

		nls.builtins.diagnostics.revive, -- golang
		nls.builtins.formatting.golines.with({
			extra_args = {
				"--max-len=180",
				"--base-formatter=gofumpt",
			},
		}),

		nls.builtins.formatting.eslint_d, -- javascript
		nls.builtins.diagnostics.eslint_d,

		nls.builtins.diagnostics.stylelint, -- css
		nls.builtins.formatting.stylelint,

		null.formatting.jq, -- json
		nls.builtins.formatting.taplo, -- toml
		nls.builtins.formatting.terraform_fmt,

		nls.builtins.formatting.zigfmt, -- zig
		nls.builtins.formatting.rustfmt, -- rust
		nls.builtins.formatting.nimpretty,
		nls.builtins.formatting.csharpier, -- cshap
		nls.builtins.formatting.shfmt, -- shell

		nls.builtins.diagnostics.typos.with({
			extra_args = {
				"--config",
				vim.fn.expand("~/nerdtools/conf/typos.toml"),
			},
		}),
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
