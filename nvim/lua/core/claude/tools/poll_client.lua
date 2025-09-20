--- Polling client that connects via WebSocket to retrieve commands
--- This replaces the stdin-based polling for daemon mode
--- @module 'core.claude.tools.poll_client'

local M = {}

local state = {
	websocket_job = nil,
	timer = nil,
	polling = false,
}

-- Python script to poll commands via WebSocket
local POLL_SCRIPT = [[
import asyncio
import websockets
import json
import sys

async def poll():
    try:
        with open('%s', 'r') as f:
            lock_data = json.load(f)
        auth_token = lock_data['authToken']

        async with websockets.connect(
            "ws://localhost:%d",
            additional_headers={"x-claude-code-ide-authorization": auth_token},
            subprotocols=["mcp"]
        ) as websocket:
            # Send poll_commands request
            await websocket.send(json.dumps({
                "jsonrpc": "2.0",
                "method": "poll_commands",
                "id": 1
            }))
            response = await websocket.recv()
            print(response)
    except Exception as e:
        print(json.dumps({"error": str(e)}))

asyncio.run(poll())
]]

-- Process commands received from polling
local function process_commands(data)
	local ok, result = pcall(vim.json.decode, data)
	if not ok then
		return
	end

	if result.result and result.result.commands then
		for _, command in ipairs(result.result.commands) do
			if command.type == "openFile" then
				vim.schedule(function()
					local file_path = command.filePath
					if file_path then
						vim.cmd.edit(file_path)
						if command.startLine then
							vim.fn.cursor(command.startLine, 1)
							if command.endLine and command.endLine > command.startLine then
								vim.cmd("normal! V")
								vim.fn.cursor(command.endLine, 1)
								vim.defer_fn(function()
									vim.cmd("normal! <Esc>")
								end, 100)
							end
						end
						vim.notify(
							string.format("Opened: %s", vim.fn.fnamemodify(file_path, ":~:.")),
							vim.log.levels.INFO
						)
					end
				end)
			end
		end
	end
end

-- Poll for commands using WebSocket
local function poll_once()
	if state.polling then
		return
	end

	-- Find the lock file
	local lock_dir = vim.fn.expand("~/.claude/ide")
	local lock_files = vim.fn.glob(lock_dir .. "/*.lock", false, true)
	if #lock_files == 0 then
		return
	end

	local lock_file = lock_files[1] -- Use first lock file
	local port = vim.fn.fnamemodify(lock_file, ":t:r")

	-- Create Python script with proper values
	local script = string.format(POLL_SCRIPT, lock_file, tonumber(port))

	-- Run Python script to poll
	state.polling = true
	vim.fn.jobstart({ "python3", "-c", script }, {
		on_stdout = function(_, data, _)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						process_commands(line)
					end
				end
			end
			state.polling = false
		end,
		on_stderr = function(_, data, _)
			state.polling = false
		end,
		on_exit = function()
			state.polling = false
		end,
	})
end

-- Start polling
function M.start()
	if state.timer then
		return
	end

	state.timer = vim.loop.new_timer()
	state.timer:start(
		1000,
		500, -- Poll every 500ms
		vim.schedule_wrap(poll_once)
	)

	vim.notify("Claude IDE WebSocket poller started", vim.log.levels.DEBUG)
end

-- Stop polling
function M.stop()
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end
	state.polling = false
end

return M