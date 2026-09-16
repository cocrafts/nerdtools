local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local M = {}
local FORMATTING = methods.internal.FORMATTING

-- Use msc fmt with temp file (stdin not supported yet)
M.format = h.make_builtin({
	name = "mscfmt",
	meta = {
		url = "https://github.com/example/metascript",
		description = "Format Metascript source code",
	},
	method = FORMATTING,
	filetypes = { "metascript" },
	generator_opts = {
		command = "msc",
		args = { "fmt", "--write", "$FILENAME" },
		to_temp_file = true,
		from_temp_file = true,
	},
	factory = h.formatter_factory,
})

return M
