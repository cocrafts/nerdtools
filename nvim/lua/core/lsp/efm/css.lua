local codespell = require("efmls-configs.linters.codespell")
local stylelint_format = require("efmls-configs.formatters.stylelint")
local stylelint_lint = require("efmls-configs.linters.stylelint")

local stylelint_markers = {
	".stylelintrc",
	".stylelintrc.cjs",
	".stylelintrc.js",
	".stylelintrc.json",
	".stylelintrc.yaml",
	".stylelintrc.yml",
	"stylelint.config.cjs",
	"stylelint.config.mjs",
	"stylelint.config.js",
}

stylelint_format.rootMarkers = stylelint_markers
stylelint_lint.rootMarkers = stylelint_markers

return {
	stylelint_format,
	stylelint_lint,
	codespell,
}
