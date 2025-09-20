--- WebSocket client for Neovim to receive commands from Claude IDE server
--- @module 'core.claude.websocket_client'

local M = {}

local state = {
	connected = false,
	port = nil,
	auth_token = nil,
	client_job = nil,
}

-- Python WebSocket client that stays connected and forwards commands
local WEBSOCKET_CLIENT = [[
import asyncio
import websockets
import json
import sys

async def client():
    try:
        with open('%s', 'r') as f:
            lock_data = json.load(f)
        auth_token = lock_data['authToken']

        async with websockets.connect(
            "ws://localhost:%d",
            additional_headers={
                "x-claude-code-ide-authorization": auth_token,
                "Sec-WebSocket-Protocol": "mcp"
            },
            subprotocols=["mcp"]
        ) as websocket:
            # Send initial connection message
            await websocket.send(json.dumps({
                "jsonrpc": "2.0",
                "method": "neovim/connected",
                "params": {"client": "neovim"},
                "id": 0
            }))

            # Poll for commands in a loop
            while True:
                # Poll every 500ms
                await asyncio.sleep(0.5)

                # Send poll request
                await websocket.send(json.dumps({
                    "jsonrpc": "2.0",
                    "method": "poll_commands",
                    "id": 1
                }))

                # Get response
                response = await websocket.recv()
                data = json.loads(response)

                # If there are commands, print them for Neovim to process
                if data.get("result") and data["result"].get("commands"):
                    for command in data["result"]["commands"]:
                        print(json.dumps(command))
                        sys.stdout.flush()

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.stdout.flush()

asyncio.run(client())
]]

-- Handle commands from the WebSocket client
local function handle_command(command)
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
	elseif command.type == "openDiff" then
		vim.notify("openDiff not yet implemented", vim.log.levels.WARN)
	end
end

-- Start WebSocket client connection
function M.start()
	if state.client_job then
		return -- Already running
	end

	-- Find lock file
	local lock_dir = vim.fn.expand("~/.claude/ide")
	local lock_files = vim.fn.glob(lock_dir .. "/*.lock", false, true)
	if #lock_files == 0 then
		vim.notify("No Claude IDE server found", vim.log.levels.WARN)
		return
	end

	local lock_file = lock_files[1]
	local port = vim.fn.fnamemodify(lock_file, ":t:r")

	-- Create Python script
	local script = string.format(WEBSOCKET_CLIENT, lock_file, tonumber(port))

	-- Start WebSocket client
	state.client_job = vim.fn.jobstart({ "python3", "-c", script }, {
		on_stdout = function(_, data, _)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						local ok, command = pcall(vim.json.decode, line)
						if ok and command then
							if command.error then
								vim.notify("WebSocket error: " .. command.error, vim.log.levels.ERROR)
							else
								handle_command(command)
							end
						end
					end
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						vim.notify("WebSocket client error: " .. line, vim.log.levels.ERROR)
					end
				end
			end
		end,
		on_exit = function()
			state.client_job = nil
			state.connected = false
			vim.notify("WebSocket client disconnected", vim.log.levels.INFO)
		end,
	})

	state.connected = true
	vim.notify("WebSocket client connected to Claude IDE", vim.log.levels.INFO)
end

-- Stop WebSocket client
function M.stop()
	if state.client_job then
		vim.fn.jobstop(state.client_job)
		state.client_job = nil
		state.connected = false
	end
end

-- Check if connected
function M.is_connected()
	return state.connected
end

return M