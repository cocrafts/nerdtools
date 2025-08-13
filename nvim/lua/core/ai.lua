local M = {}

M.configureMcpHub = function()
	require("mcphub").setup({
		config = vim.fn.expand("~/.nerdtools/conf/mcp-hub-server.json"),
		extensions = {
			avante = {
				make_slash_commands = true, -- make /slash commands from MCP server prompts
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
		-- rag_service = { enabled = true },
		system_prompt = [[
		Act as an expert software developer.
		Always use best practices when coding.
		Respect and use existing conventions, libraries, etc that are already present in the code base.]],

		-- auto_suggestions_provider = "claude",
		-- system_prompt = function()
		-- 	local hub = require("mcphub").get_hub_instance()
		-- 	return hub:get_active_servers_prompt()
		-- end,
		-- custom_tools = function()
		-- 	return { require("mcphub.extensions.avante").mcp_tool() }
		-- end,
		disabled_tools = {
			"list_files",
			"search_files",
			"read_file",
			"create_file",
			"rename_file",
			"delete_file",
			"create_dir",
			"rename_dir",
			"delete_dir",
			"bash",
		},
		behavior = {
			enable_cursor_planning_mode = true,
			enable_claude_text_editor_tool_mode = true,
		},
		mappings = {
			sidebar = {
				close = { "q" },
			},
		},
		ollama = {
			model = "qwen2.5-coder:7b-instruct",
		},
		claude = {
			endpoint = "https://api.anthropic.com",
			model = "claude-3-7-sonnet-20250219",
			temperature = 0,
			max_tokens = 4096,
		},
		openai = {
			endpoint = "https://api.openai.com/v1",
			model = "o4-mini",
			timeout = 30000, -- Timeout in milliseconds
			temperature = 0,
			max_completion_tokens = 4096,
		},
		windows = {
			sidebar_header = {
				align = "right",
			},
		},
	})
end

return M
