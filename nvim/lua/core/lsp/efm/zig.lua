local fs = require("efmls-configs.fs")

local format_bin = fs.executable("zig")
local format_args = "fmt --stdin"
local zigfmt_command = string.format("%s %s", format_bin, format_args)

local zigfmt = {
	formatCommand = zigfmt_command,
	formatStdin = true,
}

return {
	zigfmt,
}
