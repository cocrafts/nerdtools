local M = {}
local config = require("utils.config")
local json = require("core.lsp.null.json")
local nim = require("core.lsp.null.nim")
local ruff = require("core.lsp.null.ruff")
local rust = require("core.lsp.null.rust")
local terraform = require("core.lsp.null.terraform")
local typos = require("core.lsp.null.typos")
local zig = require("core.lsp.null.zig")

M.configure = function()
	local nls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local sources = {
		-- json.jqfmt,
		terraform.format,
		-- zig
		nim.format,
		zig.format,
		-- elixir
		nls.builtins.formatting.mix,
		nls.builtins.diagnostics.credo,
		nls.builtins.formatting.gleam_format,

		nls.builtins.diagnostics.stylelint, -- css
		nls.builtins.formatting.stylelint,
		nls.builtins.formatting.d2_fmt,
		nls.builtins.formatting.csharpier,
		--swift
		nls.builtins.formatting.swiftformat,
		nls.builtins.diagnostics.swiftlint,
		-- Rust
		rust.format,
		rust.taplofmt,
		-- prettier
		nls.builtins.formatting.prettier.with({
			filetypes = { "svelte" },
		}),
		-- Others
		nls.builtins.formatting.haxe_formatter,
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
		table.insert(
			sources,
			nls.builtins.formatting.clang_format.with({
				filetypes = { "c", "cpp", "cuda", "proto" },
			})
		)
	end

	if config.use_python then
		table.insert(sources, ruff.format)
		table.insert(sources, ruff.diagnostics)
		table.insert(sources, nls.builtins.diagnostics.mypy)
	end

	if config.use_go then
		local gotest = require("go.null_ls").gotest()
		local gotest_codeaction = require("go.null_ls").gotest_action()
		local golangci_lint = require("go.null_ls").golangci_lint()

		table.insert(sources, gotest)
		table.insert(sources, golangci_lint)
		table.insert(sources, gotest_codeaction)
	end

	if config.use_lua then
		table.insert(sources, nls.builtins.formatting.stylua)
		table.insert(sources, nls.builtins.diagnostics.selene)
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
