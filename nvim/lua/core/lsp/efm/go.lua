local fs = require("efmls-configs.fs")
local sourceText = require("efmls-configs.utils").sourceText
local codespell = require("efmls-configs.linters.codespell")

local linter = "revive"
local config_path = vim.fn.expand("~/nerdtools/conf/revive.toml")
local lint_bin = fs.executable(linter)
local lint_args = string.format("-config %s -formatter unix", config_path)
local command = string.format("%s %s", lint_bin, lint_args)

local revive_lint = {
	prefix = linter,
	lintSource = sourceText(linter),
	lintCommand = command,
	lintStdin = true,
	lintFormats = { "%.%#:%l:%c: %m" },
	rootMarkers = { "go.mod" },
}

local golines_bin = fs.executable("golines")
local golines_args = "--max-len 180 --base-formatter gofumpt"
local golines_command = string.format("%s %s", golines_bin, golines_args)

local golines_format = {
	formatCommand = golines_command,
	formatStdin = true,
}

return {
	golines_format,
	revive_lint,
	codespell,
}
