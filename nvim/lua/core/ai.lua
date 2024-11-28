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

M.configureAvante = function()
	require("img-clip").setup({})
	require("render-markdown").setup({})
	require("avante_lib").load()

	require("avante").setup({
		provider = "openai",
		-- auto_suggestions_provider = "openai",
		system_prompt = [[
Act as an expert software developer.
Always use best practices when coding.
Respect and use existing conventions, libraries, etc that are already present in the code base.]],
		openai = {
			endpoint = "https://api.openai.com/v1",
			model = "gpt-4o",
			timeout = 30000, -- Timeout in milliseconds
			temperature = 0,
			max_tokens = 4096,
		},
		windows = {
			sidebar_header = {
				align = "right",
			},
		},
	})
end

return M
