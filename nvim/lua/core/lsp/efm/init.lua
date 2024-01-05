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

local css_bundle = require("core.lsp.efm.css")
local go_bundle = require("core.lsp.efm.go")
local zig_bundle = require("core.lsp.efm.zig")

local languages = {
	c = { clang_format, clang_tidy },
	lua = { stylua, selene },
	python = { mypy_lint, ruff_lint, ruff_format },
	json = { jq_format, jq_lint },
	jsonc = { jq_format, jq_lint },
	vue = { eslint_d_format, eslint_d_lint },
	typescript = { eslint_d_format, eslint_d_lint },
	typescriptreact = { eslint_d_format, eslint_d_lint },
	javascript = { eslint_d_format, eslint_d_lint },
	javascriptreact = { eslint_d_format, eslint_d_lint },
	css = css_bundle,
	scss = css_bundle,
	sass = css_bundle,
	less = css_bundle,
	go = go_bundle,
	zig = zig_bundle,
	rust = { rustfmt },
	sh = { shfmt },
}

local M = {}
M.configure = function(lspconfig)
	lspconfig.efm.setup({
		filetypes = vim.tbl_keys(languages),
		settings = {
			rootMarkers = { ".git/" },
			languages = languages,
		},
		init_options = {
			documentFormatting = true,
			documentRangeFormatting = true,
		},
	})
end

return M
