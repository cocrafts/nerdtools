local M = {}

local function greeting()
	local hour = tonumber(vim.fn.strftime("%H"))
	local day_part = ({ "evening", "morning", "afternoon", "evening" })[math.floor((hour + 4) / 8) + 1]
	local username = vim.uv.os_get_passwd().username or "USERNAME"
	return ("Good %s, %s"):format(day_part, username)
end

local function cowsay(text)
	local border = string.rep("_", vim.fn.strdisplaywidth(text) + 2)
	return table.concat({
		" " .. border,
		"< " .. text .. " >",
		" " .. string.rep("-", #border),
		"        \\   ^__^",
		"         \\  (oo)\\_______",
		"            (__)\\       )\\/\\",
		"                ||----w |",
		"                ||     ||",
	}, "\n")
end

M.configure = function()
	require("mini.starter").setup({
		header = function()
			return cowsay(greeting())
		end,
	})
end

return M
