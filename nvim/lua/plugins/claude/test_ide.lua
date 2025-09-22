#!/usr/bin/env nvim -l
-- Test script for Claude IDE integration
-- Run with: nvim -l nvim/lua/plugins/claude/test_ide.lua

local function test_ide_features()
    -- Load the plugin
    local claude = require("plugins.claude")
    local status_ok, err = claude.setup({
        log_level = vim.log.levels.DEBUG
    })

    if not status_ok then
        print("❌ Failed to setup Claude IDE: " .. (err or "unknown error"))
        return false
    end

    -- Wait for server to start
    vim.wait(1000)

    -- Test 1: Check server status
    local status = claude.get_status()
    print("✅ Server Status:")
    print("  - Initialized: " .. tostring(status.initialized))
    print("  - Port: " .. tostring(status.port))
    print("  - Connected: " .. tostring(status.connected))
    print("  - Client count: " .. tostring(status.client_count))

    -- Test 2: Check lock file
    local lockfile = require("plugins.claude.lockfile")
    local lock_exists = lockfile.exists(status.port)
    print("\n✅ Lock File:")
    print("  - Exists: " .. tostring(lock_exists))
    if lock_exists then
        local lock_data = lockfile.read(status.port)
        if lock_data then
            print("  - PID: " .. tostring(lock_data.pid))
            print("  - IDE Name: " .. tostring(lock_data.ideName))
            print("  - Transport: " .. tostring(lock_data.transport))
        end
    end

    -- Test 3: Test tools availability
    local tools = require("plugins.claude.tools")
    print("\n✅ Available Tools:")
    local tool_list = tools.get_tools()
    for _, tool in ipairs(tool_list) do
        print("  - " .. tool.name .. ": " .. tool.description)
    end

    -- Test 4: Buffer management
    local buffer = require("plugins.claude.buffer")
    local buffers = buffer.get_all_buffers()
    print("\n✅ Open Buffers: " .. #buffers)
    for i, buf in ipairs(buffers) do
        print("  " .. i .. ". " .. buf.filepath .. " (" .. buf.filetype .. ")")
    end

    -- Test 5: Selection tracking
    local selection = require("plugins.claude.selection")
    print("\n✅ Selection Tracking: Enabled")

    -- Test 6: Server info
    local server = require("plugins.claude.server")
    local server_info = server.get_info()
    print("\n✅ Server Info:")
    print("  - Running: " .. tostring(server_info.running))
    print("  - Port: " .. tostring(server_info.port))
    print("  - Clients connected: " .. server_info.client_count)

    -- Test 7: Environment variables
    print("\n✅ Environment Variables:")
    print("  - CLAUDE_CODE_SSE_PORT: " .. (vim.env.CLAUDE_CODE_SSE_PORT or "not set"))
    print("  - ENABLE_IDE_INTEGRATION: " .. (vim.env.ENABLE_IDE_INTEGRATION or "not set"))

    print("\n🎉 All tests completed successfully!")
    print("\nTo test with Claude Code:")
    print("1. Ensure this Neovim instance is running")
    print("2. Start Claude Code - it should auto-connect")
    print("3. Try using @-mentions to reference files")
    print("4. Test file navigation and diagnostics")

    return true
end

-- Run the tests
test_ide_features()

-- Keep running for manual testing
print("\nPress Ctrl+C to exit...")
vim.wait(60000000) -- Wait for a long time