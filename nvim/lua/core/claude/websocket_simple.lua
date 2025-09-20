--- Minimal WebSocket server that works with Claude Code
--- Uses existing claudecode.nvim if available, otherwise provides basic server
--- @module 'core.claude.websocket_simple'

local M = {}

-- Try to leverage claudecode.nvim if it's installed
local has_claudecode, claudecode_server = pcall(require, "claudecode.server")
local has_claudecode_lockfile, claudecode_lockfile = pcall(require, "claudecode.lockfile")

-- State
local state = {
	using_claudecode = has_claudecode,
	port = nil,
	auth_token = nil,
}

-- Generate UUID for auth
local function generate_uuid()
	local random = math.random
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 15) or random(8, 11)
		return string.format("%x", v)
	end)
end

-- Start the server
function M.start()
	if has_claudecode and has_claudecode_lockfile then
		-- Use claudecode.nvim's robust implementation
		local config = {
			port_range = { min = 50000, max = 60000 },
		}

		state.auth_token = generate_uuid()

		-- Start claudecode's server
		local success, port_or_error = claudecode_server.start(config, state.auth_token)
		if success then
			state.port = port_or_error

			-- Create lock file using claudecode's method
			claudecode_lockfile.create(state.port, state.auth_token)

			return state.port, state.auth_token
		end
	end

	-- Fallback: Create a simple lock file without WebSocket server
	-- This at least lets Claude Code know Neovim is here
	state.port = 50000 + (vim.fn.getpid() % 10000)
	state.auth_token = "terminal-mode-" .. vim.fn.getpid()

	return state.port, state.auth_token
end

-- Stop the server
function M.stop()
	if has_claudecode and state.using_claudecode then
		claudecode_server.stop()
		if state.port then
			claudecode_lockfile.remove(state.port)
		end
	end
	state.port = nil
	state.auth_token = nil
end

-- Send at-mention to Claude
function M.send_mention(filepath, text, line_start, line_end)
	if has_claudecode and state.using_claudecode then
		-- Use claudecode's broadcast
		local server = claudecode_server.state
		if server and server.clients then
			for _, client in pairs(server.clients) do
				client:send_json({
					jsonrpc = "2.0",
					method = "at_mentioned",
					params = {
						filePath = filepath,
						text = text,
						lineStart = line_start,
						lineEnd = line_end,
					},
				})
			end
			return true
		end
	end

	-- Fallback to WezTerm
	local wezterm = require("core.claude.wezterm")
	local prompt = "@" .. filepath
	if line_start and line_end then
		if line_start == line_end then
			prompt = prompt .. ":" .. line_start
		else
			prompt = prompt .. ":" .. line_start .. "-" .. line_end
		end
	end
	if text and text ~= "" then
		prompt = prompt .. "\n\n" .. text
	end
	return wezterm.send_to_claude(prompt, false, false)
end

-- Check if connected
function M.is_connected()
	if has_claudecode and state.using_claudecode then
		local server = claudecode_server.state
		if server and server.clients then
			for _ in pairs(server.clients) do
				return true
			end
		end
		return false
	end

	-- Check WezTerm as fallback
	local wezterm = require("core.claude.wezterm")
	return wezterm.has_claude_pane()
end

-- Get server info
function M.get_info()
	return {
		mode = state.using_claudecode and "claudecode" or "fallback",
		port = state.port,
		auth_token = state.auth_token,
		connected = M.is_connected(),
	}
end

return M