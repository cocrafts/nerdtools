local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local M = {}
local FORMATTING = methods.internal.FORMATTING

M.format = h.make_builtin({
	name = "rustfmt",
	meta = {
		url = "https://github.com/rust-lang/rustfmt",
		description = "A tool for formatting rust code according to style guidelines.",
		notes = {
			"`--edition` defaults to `2015`. To set a different edition, use `extra_args`.",
			"See [the wiki](https://github.com/nvimtools/none-ls.nvim/wiki/Source-specific-Configuration#rustfmt) for other workarounds.",
		},
	},
	method = FORMATTING,
	filetypes = { "rust" },
	generator_opts = {
		command = "rustfmt",
		args = { "--emit=stdout" },
		to_stdin = true,
	},
	factory = h.formatter_factory,
})

M.taplofmt = h.make_builtin({
	name = "taplo",
	meta = {
		url = "https://taplo.tamasfe.dev/",
		description = "A versatile, feature-rich TOML toolkit.",
	},
	method = FORMATTING,
	filetypes = { "toml" },
	generator_opts = {
		command = "taplo",
		args = { "format", "-" },
		to_stdin = true,
	},
	factory = h.formatter_factory,
})

return M
