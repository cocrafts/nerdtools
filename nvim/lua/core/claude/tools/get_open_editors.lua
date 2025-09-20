--- Tool for getting all open editors/buffers
--- @module 'core.claude.tools.get_open_editors'

local M = {}

M.name = "get_open_editors"

M.schema = {
	description = "Get a list of all currently open editors/buffers",
	inputSchema = {
		type = "object",
		properties = {
			include_hidden = {
				type = "boolean",
				description = "Include hidden buffers (default: false)",
			},
			include_unloaded = {
				type = "boolean",
				description = "Include unloaded buffers (default: false)",
			},
		},
		additionalProperties = false,
	},
}

--- Get buffer information
--- @param bufnr number Buffer number
--- @return table|nil Buffer info
local function get_buffer_info(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return nil -- Skip unnamed buffers
	end

	local modified = vim.api.nvim_buf_get_option(bufnr, "modified")
	local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
	local loaded = vim.api.nvim_buf_is_loaded(bufnr)
	local hidden = vim.api.nvim_buf_get_option(bufnr, "bufhidden") ~= ""

	-- Get cursor position if buffer is in a window
	local cursor = nil
	local windows = vim.fn.win_findbuf(bufnr)
	if #windows > 0 then
		local winid = windows[1]
		local pos = vim.api.nvim_win_get_cursor(winid)
		cursor = {
			line = pos[1],
			column = pos[2] + 1, -- Convert to 1-based
		}
	end

	return {
		bufnr = bufnr,
		filepath = filepath,
		uri = "file://" .. filepath,
		modified = modified,
		filetype = filetype,
		loaded = loaded,
		hidden = hidden,
		cursor = cursor,
		windows = #windows,
	}
end

--- Handle get_open_editors tool invocation
--- @param params table Input parameters
--- @return table Response with open editors list
function M.handler(params)
	params = params or {}
	local include_hidden = params.include_hidden or false
	local include_unloaded = params.include_unloaded or false

	local buffers = {}
	local buffer_list = vim.api.nvim_list_bufs()

	for _, bufnr in ipairs(buffer_list) do
		local info = get_buffer_info(bufnr)

		if info then
			-- Apply filters
			local should_include = true

			if not include_hidden and info.hidden then
				should_include = false
			end

			if not include_unloaded and not info.loaded then
				should_include = false
			end

			-- Skip special buffers
			if info.filetype == "netrw" or info.filetype == "TelescopePrompt" then
				should_include = false
			end

			if should_include then
				table.insert(buffers, info)
			end
		end
	end

	-- Sort by buffer number
	table.sort(buffers, function(a, b)
		return a.bufnr < b.bufnr
	end)

	-- Format response
	local response_text = "Open editors: " .. #buffers .. "\n\n"

	if #buffers > 0 then
		for _, buf in ipairs(buffers) do
			response_text = response_text .. string.format("Buffer %d: %s", buf.bufnr, buf.filepath)

			local details = {}
			if buf.modified then
				table.insert(details, "modified")
			end
			if buf.filetype ~= "" then
				table.insert(details, buf.filetype)
			end
			if buf.windows > 0 then
				table.insert(details, buf.windows .. " window(s)")
			end
			if buf.cursor then
				table.insert(details, string.format("cursor at %d:%d", buf.cursor.line, buf.cursor.column))
			end

			if #details > 0 then
				response_text = response_text .. " (" .. table.concat(details, ", ") .. ")"
			end

			response_text = response_text .. "\n"
		end
	else
		response_text = response_text .. "No open editors found."
	end

	return {
		content = {
			{
				type = "text",
				text = response_text,
			},
		},
		_raw_buffers = buffers,
	}
end

return M