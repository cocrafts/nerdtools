local M = {}

local function highlight(group, properties)
	local bg = properties.bg == nil and "" or "guibg=" .. properties.bg
	local fg = properties.fg == nil and "" or "guifg=" .. properties.fg
	local style = properties.style == nil and "" or "gui=" .. properties.style

	local cmd = table.concat({
		"highlight",
		group,
		bg,
		fg,
		style,
	}, " ")

	vim.api.nvim_command(cmd)
end

local configs = {
	no_bold = false,
	no_itatlic = false,
}

local styles = {
	maybe_bold = configs.no_bold == true and "NONE" or "bold",
	maybe_italic = configs.no_itatlic == true and "NONE" or "italic",
}

M.styles = styles
M.configs = configs
M.initialize = function(skeleton)
	for group, properties in pairs(skeleton) do
		highlight(group, properties)
	end
end

return M
