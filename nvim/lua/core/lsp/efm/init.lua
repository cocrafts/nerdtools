local clang_format = require("efmls-configs.formatters.clang_format")
local clang_tidy = require("efmls-configs.linters.clang_tidy")
local eslint_d_format = require("efmls-configs.formatters.eslint_d")
local eslint_d_lint = require("efmls-configs.linters.eslint_d")
local jq_format = require("efmls-configs.formatters.jq")
local jq_lint = require("efmls-configs.linters.jq")
local mypy_lint = require("efmls-configs.linters.mypy")
local ruff_format = require("efmls-configs.formatters.ruff")
local ruff_lint = require("efmls-configs.linters.ruff")
local rustfmt = require("efmls-configs.formatters.rustfmt")
local selene = require("efmls-configs.linters.selene")
local shfmt = require("efmls-configs.formatters.shfmt")
local stylua = require("efmls-configs.formatters.stylua")
local taplo_format = require("efmls-configs.formatters.taplo")
local terraform_format = require("efmls-configs.formatters.terraform_fmt")

local css_bundle = require("core.lsp.efm.css")
local go_bundle = require("core.lsp.efm.go")
local zig_bundle = require("core.lsp.efm.zig")
local json_bundle = { jq_format, jq_lint }
local eslint_bundle = { eslint_d_format, eslint_d_lint }

local M = {}
local languages = {
	c = { clang_format, clang_tidy },
	lua = { stylua, selene },
	python = { mypy_lint, ruff_lint, ruff_format },
	json = json_bundle,
	jsonc = json_bundle,
	vue = eslint_bundle,
	typescript = eslint_bundle,
	typescriptreact = eslint_bundle,
	javascript = eslint_bundle,
	javascriptreact = eslint_bundle,
	css = css_bundle,
	scss = css_bundle,
	sass = css_bundle,
	less = css_bundle,
	go = go_bundle,
	zig = zig_bundle,
	rust = { rustfmt },
	sh = { shfmt },
	toml = { taplo_format },
	terraform = { terraform_format },
}

M.configure = function(lspconfig)
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

	local configs = {
		filetypes = vim.tbl_keys(languages),
		settings = {
			rootMarkers = { ".git/" },
			languages = languages,
		},
		init_options = {
			documentFormatting = true,
			documentRangeFormatting = true,
		},
	}

	lspconfig.efm.setup(vim.tbl_extend("force", configs, {
		on_attach = function(_, bufnr)
			local efm = vim.lsp.get_clients({ name = "efm" })
			if not vim.tbl_isempty(efm) then
				vim.api.nvim_clear_autocmds({
					group = augroup,
					buffer = bufnr,
				})

				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					callback = function()
						vim.lsp.buf.format({ name = "efm" })
						vim.api.nvim_buf_call(bufnr, function()
							vim.cmd("w")
						end)
					end,
				})
			end
		end,
	}))
end

return M
