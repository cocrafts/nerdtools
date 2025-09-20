--- Diagnostics handler for Claude IDE integration
--- Sends LSP diagnostics to Claude Code through WebSocket
--- @module 'core.claude.diagnostics'

local M = {}
local websocket = require("core.claude.websocket")

-- Cache for diagnostics to avoid sending duplicates
local last_diagnostics = {}

--- Convert Neovim diagnostic to Claude-friendly format
--- @param diagnostic table Neovim diagnostic
--- @param bufnr number Buffer number
--- @return table Formatted diagnostic
local function format_diagnostic(diagnostic, bufnr)
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "error",
		[vim.diagnostic.severity.WARN] = "warning",
		[vim.diagnostic.severity.INFO] = "info",
		[vim.diagnostic.severity.HINT] = "hint",
	}

	local filepath = vim.api.nvim_buf_get_name(bufnr)

	return {
		filepath = filepath,
		line = diagnostic.lnum + 1, -- Convert to 1-based
		column = diagnostic.col + 1,
		end_line = diagnostic.end_lnum and (diagnostic.end_lnum + 1) or (diagnostic.lnum + 1),
		end_column = diagnostic.end_col and (diagnostic.end_col + 1) or (diagnostic.col + 1),
		severity = severity_map[diagnostic.severity] or "info",
		message = diagnostic.message,
		source = diagnostic.source,
		code = diagnostic.code,
	}
end

--- Send diagnostics update to Claude
--- @param bufnr number|nil Buffer number (nil for all buffers)
function M.send_diagnostics_update(bufnr)
	if not websocket.is_connected() then
		return
	end

	local diagnostics_by_file = {}

	if bufnr then
		-- Get diagnostics for specific buffer
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		if filepath ~= "" then
			local diagnostics = vim.diagnostic.get(bufnr)
			local formatted = {}
			for _, diag in ipairs(diagnostics) do
				table.insert(formatted, format_diagnostic(diag, bufnr))
			end
			diagnostics_by_file[filepath] = formatted
		end
	else
		-- Get diagnostics for all buffers
		local all_diagnostics = vim.diagnostic.get()
		for _, diag in ipairs(all_diagnostics) do
			local filepath = vim.api.nvim_buf_get_name(diag.bufnr)
			if filepath ~= "" then
				if not diagnostics_by_file[filepath] then
					diagnostics_by_file[filepath] = {}
				end
				table.insert(diagnostics_by_file[filepath], format_diagnostic(diag, diag.bufnr))
			end
		end
	end

	-- Check if diagnostics have changed
	local diagnostics_json = vim.json.encode(diagnostics_by_file)
	if diagnostics_json == vim.json.encode(last_diagnostics) then
		return -- No changes
	end
	last_diagnostics = diagnostics_by_file

	-- Send diagnostics notification through WebSocket
	websocket.send_notification("diagnostics_updated", {
		diagnostics = diagnostics_by_file,
		timestamp = os.time(),
	})
end

--- Setup diagnostics monitoring
function M.setup()
	-- Create autocmd to monitor diagnostic changes
	local augroup = vim.api.nvim_create_augroup("ClaudeDiagnostics", { clear = true })

	-- Send diagnostics when they change
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = augroup,
		callback = function(args)
			-- Debounce to avoid too many updates
			vim.defer_fn(function()
				M.send_diagnostics_update(args.buf)
			end, 100)
		end,
		desc = "Send diagnostics to Claude Code",
	})

	-- Send diagnostics when connecting
	vim.api.nvim_create_autocmd("User", {
		group = augroup,
		pattern = "ClaudeIDEConnected",
		callback = function()
			-- Send all current diagnostics
			M.send_diagnostics_update()
		end,
		desc = "Send initial diagnostics on connection",
	})
end

return M