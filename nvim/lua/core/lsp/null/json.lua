local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local M = {}
local FORMATTING = methods.internal.FORMATTING

M.jqfmt = h.make_builtin({
	name = "jq",
	meta = {
		url = "https://github.com/stedolan/jq",
		description = "Command-line JSON processor",
	},
	method = FORMATTING,
	factory = h.formatter_factory,
	filetypes = { "json" },
	generator_opts = {
		command = "jq",
		to_stdin = true,
		args = { "--indent", "4" },
	},
})

return M
