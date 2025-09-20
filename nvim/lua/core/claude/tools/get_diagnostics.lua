--- Tool implementation for getting LSP diagnostics
--- Provides Claude with error/warning information from Neovim
--- @module 'core.claude.tools.get_diagnostics'

local M = {}

M.name = "get_diagnostics"

M.schema = {
	description = "Get language diagnostics (errors, warnings) from the editor",
	inputSchema = {
		type = "object",
		properties = {
			uri = {
				type = "string",
				description = "Optional file URI to get diagnostics for. If not provided, gets diagnostics for all open files.",
			},
			severity = {
				type = "string",
				enum = { "error", "warning", "info", "hint", "all" },
				description = "Filter by severity level. Defaults to 'all'.",
			},
		},
		additionalProperties = false,
	},
}

--- Convert Neovim diagnostic to MCP format
--- @param diagnostic table Neovim diagnostic
--- @param bufnr number Buffer number
--- @return table MCP diagnostic
local function convert_diagnostic(diagnostic, bufnr)
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "error",
		[vim.diagnostic.severity.WARN] = "warning",
		[vim.diagnostic.severity.INFO] = "info",
		[vim.diagnostic.severity.HINT] = "hint",
	}

	local filepath = vim.api.nvim_buf_get_name(bufnr)

	-- Convert 0-based to 1-based for line/column numbers
	return {
		uri = "file://" .. filepath,
		filepath = filepath,
		range = {
			start = {
				line = diagnostic.lnum + 1,
				character = diagnostic.col + 1,
			},
			["end"] = {
				line = diagnostic.end_lnum and (diagnostic.end_lnum + 1) or (diagnostic.lnum + 1),
				character = diagnostic.end_col and (diagnostic.end_col + 1) or (diagnostic.col + 1),
			},
		},
		severity = severity_map[diagnostic.severity] or "info",
		message = diagnostic.message,
		source = diagnostic.source,
		code = diagnostic.code,
	}
end

--- Handle get_diagnostics tool invocation
--- @param params table Input parameters
--- @return table Response with diagnostics
function M.handler(params)
	if not vim.diagnostic or not vim.diagnostic.get then
		error({
			code = -32000,
			message = "Feature unavailable",
			data = "Diagnostics not available in this Neovim version",
		})
	end

	params = params or {}
	local severity = params.severity or "all"
	local uri = params.uri

	-- Build severity filter
	local severity_filter = nil
	if severity ~= "all" then
		local severity_levels = {
			error = vim.diagnostic.severity.ERROR,
			warning = vim.diagnostic.severity.WARN,
			info = vim.diagnostic.severity.INFO,
			hint = vim.diagnostic.severity.HINT,
		}
		severity_filter = { severity = severity_levels[severity] }
	end

	local diagnostics_data = {}

	if uri then
		-- Get diagnostics for specific file
		local filepath = uri:gsub("^file://", "")
		local bufnr = vim.fn.bufnr(filepath)

		if bufnr == -1 then
			return {
				content = {
					{
						type = "text",
						text = "File not open: " .. filepath,
					},
				},
			}
		end

		local diagnostics = vim.diagnostic.get(bufnr, severity_filter)
		for _, diagnostic in ipairs(diagnostics) do
			table.insert(diagnostics_data, convert_diagnostic(diagnostic, bufnr))
		end
	else
		-- Get diagnostics for all buffers
		local all_diagnostics = vim.diagnostic.get(nil, severity_filter)
		local diagnostics_by_buffer = {}

		-- Group diagnostics by buffer
		for _, diagnostic in ipairs(all_diagnostics) do
			local bufnr = diagnostic.bufnr
			if not diagnostics_by_buffer[bufnr] then
				diagnostics_by_buffer[bufnr] = {}
			end
			table.insert(diagnostics_by_buffer[bufnr], diagnostic)
		end

		-- Convert diagnostics
		for bufnr, buffer_diagnostics in pairs(diagnostics_by_buffer) do
			for _, diagnostic in ipairs(buffer_diagnostics) do
				table.insert(diagnostics_data, convert_diagnostic(diagnostic, bufnr))
			end
		end
	end

	-- Sort diagnostics by file and line
	table.sort(diagnostics_data, function(a, b)
		if a.filepath ~= b.filepath then
			return a.filepath < b.filepath
		end
		return a.range.start.line < b.range.start.line
	end)

	-- Format response
	local response_text = "Diagnostics found: " .. #diagnostics_data .. "\n\n"

	if #diagnostics_data > 0 then
		local current_file = nil
		for _, diag in ipairs(diagnostics_data) do
			if current_file ~= diag.filepath then
				current_file = diag.filepath
				response_text = response_text .. "\n" .. diag.filepath .. ":\n"
			end

			response_text = response_text .. string.format(
				"  [%s] Line %d:%d: %s",
				diag.severity:upper(),
				diag.range.start.line,
				diag.range.start.character,
				diag.message
			)

			if diag.source then
				response_text = response_text .. " (" .. diag.source .. ")"
			end

			response_text = response_text .. "\n"
		end
	else
		response_text = response_text .. "No diagnostics found."
	end

	return {
		content = {
			{
				type = "text",
				text = response_text,
			},
		},
		-- Include raw data for programmatic use
		_raw_diagnostics = diagnostics_data,
	}
end

return M