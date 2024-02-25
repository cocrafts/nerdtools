local M = {}
local eslint = require("core.lsp.null.eslint")
local json = require("core.lsp.null.json")
local ruff = require("core.lsp.null.ruff")
local rust = require("core.lsp.null.rust")
local terraform = require("core.lsp.null.terraform")
local typos = require("core.lsp.null.typos")
local zig = require("core.lsp.null.zig")

M.configure = function()
	local nls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local sources = {
		nls.builtins.formatting.clang_format, -- clang

		nls.builtins.formatting.stylua, -- lua
		nls.builtins.diagnostics.selene,

		ruff.format, -- python
		ruff.diagnostics,
		nls.builtins.diagnostics.mypy,

		nls.builtins.diagnostics.revive, -- golang
		nls.builtins.formatting.golines.with({
			extra_args = {
				"--max-len=180",
				"--base-formatter=gofumpt",
			},
		}),

		eslint.format,
		eslint.diagnostics,

		nls.builtins.diagnostics.stylelint, -- css
		nls.builtins.formatting.stylelint,

		json.jqfmt,
		terraform.format,

		zig.format,
		rust.format,
		rust.taplofmt,
		nls.builtins.formatting.nimpretty,
		nls.builtins.formatting.csharpier, -- cshap
		nls.builtins.formatting.shfmt.with({ -- shell
			filetypes = { "sh", "zsh" },
		}),
		typos.diagnostic.with({
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
