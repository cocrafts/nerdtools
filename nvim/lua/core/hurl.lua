local M = {}

M.configure = function()
	require("hurl").setup({
		debug = false,
		show_notification = false,
		mode = "split",
		split_position = "right",
		formatters = {
			json = { "jq" }, -- Make sure you have install jq in your system, e.g: brew install jq
			html = {
				"prettier", -- Make sure you have install prettier in your system, e.g: npm install -g prettier
				"--parser",
				"html",
			},
		},
	})
end

return M
