--- MCP Tools management for Claude IDE integration
--- @module 'core.claude.tools'

local M = {}

M.ERROR_CODES = {
	PARSE_ERROR = -32700,
	INVALID_REQUEST = -32600,
	METHOD_NOT_FOUND = -32601,
	INVALID_PARAMS = -32602,
	INTERNAL_ERROR = -32000,
}

M.tools = {}

--- Setup the tools module
function M.setup()
	M.register_all()
end

--- Get the complete tool list for MCP tools/list handler
function M.get_tool_list()
	local tool_list = {}

	for name, tool_data in pairs(M.tools) do
		if tool_data.schema then
			local tool_def = {
				name = name,
				description = tool_data.schema.description,
				inputSchema = tool_data.schema.inputSchema,
			}
			table.insert(tool_list, tool_def)
		end
	end

	return tool_list
end

--- Register all available tools
function M.register_all()
	-- Register diagnostic tool
	local get_diagnostics = require("core.claude.tools.get_diagnostics")
	M.register(get_diagnostics)

	-- Register open editors tool
	local get_open_editors = require("core.claude.tools.get_open_editors")
	M.register(get_open_editors)

	-- Register workspace folders tool
	local get_workspace_folders = require("core.claude.tools.get_workspace_folders")
	M.register(get_workspace_folders)

	-- More tools can be added here
end

--- Register a tool
--- @param tool_module table Tool module with name, handler, and schema
function M.register(tool_module)
	if not tool_module or not tool_module.name or not tool_module.handler then
		vim.notify("Error registering tool: Invalid tool module structure", vim.log.levels.ERROR)
		return
	end

	M.tools[tool_module.name] = {
		handler = tool_module.handler,
		schema = tool_module.schema,
		requires_coroutine = tool_module.requires_coroutine,
	}
end

--- Handle tool invocation from MCP
--- @param params table MCP tool invocation parameters
--- @return table MCP response
function M.handle_invoke(params)
	local tool_name = params.name
	local input = params.arguments or {}

	if not M.tools[tool_name] then
		return {
			error = {
				code = M.ERROR_CODES.METHOD_NOT_FOUND,
				message = "Tool not found: " .. tool_name,
			},
		}
	end

	local tool_data = M.tools[tool_name]

	-- Execute tool handler with error handling
	local success, result = pcall(tool_data.handler, input)

	if not success then
		-- Handle error response
		if type(result) == "table" and result.code then
			-- Structured error
			return {
				error = result,
			}
		else
			-- String error
			return {
				error = {
					code = M.ERROR_CODES.INTERNAL_ERROR,
					message = tostring(result),
				},
			}
		end
	end

	-- Success response
	return result
end

return M