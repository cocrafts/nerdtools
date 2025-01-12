local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local M = {}
local FORMATTING = methods.internal.FORMATTING

M.format = h.make_builtin({
	name = "nph",
	meta = {
		url = "https://github.com/arnetheduck/nph",
		description = "Opinionated source code formatter for the Nim language",
	},
	method = FORMATTING,
	filetypes = { "nim" },
	generator_opts = {
		command = "nph",
		args = { "-" },
		to_stdin = true,
	},
	factory = h.formatter_factory,
})

return M
