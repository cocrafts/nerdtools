local M = {}
local config = require("utils.config")
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
		eslint.format,
		eslint.diagnostics,

		json.jqfmt,
		terraform.format,

		nls.builtins.diagnostics.stylelint, -- css
		nls.builtins.formatting.stylelint,

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

	if config.use_clang then
		table.insert(sources, nls.builtins.formatting.clang_format)
	end

	if config.use_python then
		table.insert(sources, ruff.format)
		table.insert(sources, ruff.diagnostics)
		table.insert(sources, nls.builtins.diagnostics.mypy)
	end

	if config.use_go then
		local gotest_codeaction = require("go.null_ls").gotest_action()
		local golangci_lint = require("go.null_ls").golangci_lint()
		local gotest = require("go.null_ls").gotest()

		table.insert(sources, gotest)
		table.insert(sources, golangci_lint)
		table.insert(sources, gotest_codeaction)
	end

	if config.use_haxe then
		table.insert(sources, nls.builtins.formatting.haxe_formatter)
	end

	if config.use_lua then
		table.insert(sources, nls.builtins.formatting.stylua)
		table.insert(sources, nls.builtins.diagnostics.selene)
	end

	if config.use_zig then
		table.insert(sources, zig.format)
	end

	if config.use_rust then
		table.insert(sources, rust.format)
		table.insert(sources, rust.taplofmt)
	end

	if config.use_swift then
		table.insert(sources, nls.builtins.formatting.swiftformat)
		table.insert(sources, nls.builtins.diagnostics.swiftlint)
	end

	if config.use_nim then
		table.insert(sources, nls.builtins.formatting.nimpretty)
	end

	if config.use_csharp then
		table.insert(sources, nls.builtins.formatting.csharpier)
	end

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
