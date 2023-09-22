local ft = require("guard.filetype")
local lint = require("guard.lint")
local M = {}

M.configure = function()
	ft("lua"):fmt({
		cmd = "stylua",
		args = { "-" },
		stdin = true,
	}):lint({
		cmd = "selene",
		args = { "--no-summary", "--display-style", "json2" },
		stdin = true,
		parse = lint.from_json({
			attributes = {
				lnum = function(offence)
					return offence.primary_label.span.start_line
				end,
				col = function(offence)
					return offence.primary_label.span.start_column
				end,
			},
			severities = {
				Error = lint.severities.error,
				Warning = lint.severities.warning,
			},
			lines = true,
			offset = 0,
			source = "selene",
		}),
	})

	ft("javascript,javascriptreact,typescript,typescriptreact,vue"):fmt({
		cmd = "eslint_d",
		args = { "--fix-to-stdout", "--stdin", "--stdin-filename" },
		fname = true,
		stdin = true,
	}):lint({
		cmd = "eslint_d",
		args = { "--format", "json", "--stdin", "--stdin-filename" },
		fname = true,
		stdin = true,
		find = {
			".eslintrc.js",
			".eslintrc.cjs",
			".eslintrc.yaml",
			".eslintrc.yml",
			".eslintrc.json",
		},
		parse = lint.from_json({
			get_diagnostics = function(...)
				return vim.json.decode(...)[1].messages
			end,
			attributes = {
				lnum = "line",
				end_lnum = "endLine",
				col = "column",
				end_col = "endColumn",
				message = "message",
				code = "ruleId",
			},
			severities = {
				lint.severities.warning,
				lint.severities.error,
			},
			source = "eslint_d",
		}),
	})

	ft("json"):fmt({ cmd = "jq", stdin = true })

	ft("scss,less,sass,css"):lint({
		cmd = "stylelint",
		args = { "--formatter", "json", "--stdin", "--stdin-filename" },
		stdin = true,
		fname = true,
		find = {
			".stylelintrc",
			".stylelintrc.cjs",
			".stylelintrc.js",
			".stylelintrc.json",
			".stylelintrc.yaml",
			".stylelintrc.yml",
			"stylelint.config.cjs",
			"stylelint.config.mjs",
			"stylelint.config.js",
		},
		parse = lint.from_json({
			get_diagnostics = function(...)
				return vim.json.decode(...)[1].warnings
			end,
			attributes = {
				lnum = "line",
				end_lnum = "endLine",
				col = "column",
				end_col = "endColumn",
				message = "text",
				code = "rule",
			},
			severities = {
				warning = lint.severities.warning,
				error = lint.severities.error,
			},
			source = "stylelint",
		}),
	})

	ft("zig"):fmt({
		cmd = "zigfmt",
		args = { "fmt", "--stdin" },
		stdin = true,
	})

	ft("rust"):fmt({
		cmd = "rustfmt",
		args = { "--edition", "2021", "--emit", "stdout" },
		stdin = true,
	})

	ft("go"):fmt({
		cmd = "golines",
		args = { "--max-len", "180", "--base-formatter=gofumpt" },
		stdin = true,
	})

	ft("cs"):fmt({
		cmd = "dotnet-csharpier",
		args = { "--write-stdout" },
		stdin = true,
	})

	ft("shfmt"):fmt({
		cmd = "shfmt",
		stdin = true,
	})

	require("guard").setup({
		fmt_on_save = true,
		lsp_as_default_formatter = false,
	})
end

return M
