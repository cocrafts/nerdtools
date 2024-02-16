local M = {}

M.configureGPT = function()
	require("chatgpt").setup({
		openai_params = {
			model = "gpt-4-turbo-preview",
		},
		openai_edit_params = {
			model = "gpt-4-turbo-preview",
		},
		popup_layout = {
			default = "center",
			center = {
				width = 0.98,
				height = 0.96,
			},
		},
	})
end

M.configureCodeium = function()
	require("codeium").setup({})
end

return M
