local M = {}

M.configureAvante = function()
	require("img-clip").setup({})
	require("render-markdown").setup({})
	require("avante_lib").load()

	require("avante").setup({
		provider = "claude",
		-- auto_suggestions_provider = "claude",
		system_prompt = [[
Act as an expert software developer.
Always use best practices when coding.
Respect and use existing conventions, libraries, etc that are already present in the code base.]],
		rag_service = { enabled = true },
		behavior = {
			enable_cursor_planning_mode = true,
			enable_claude_text_editor_tool_mode = true,
		},
		mappings = {
			sidebar = {
				close = { "q" },
			},
		},
		claude = {
			endpoint = "https://api.anthropic.com",
			model = "claude-3-7-sonnet-20250219",
			temperature = 0,
			max_tokens = 4096,
		},
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
