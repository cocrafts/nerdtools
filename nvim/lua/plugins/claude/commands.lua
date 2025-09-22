---@brief Claude IDE commands for Neovim
---@module 'plugins.claude.commands'

local M = {}

local server = require("plugins.claude.server")
local lockfile = require("plugins.claude.lockfile")

--- Create user commands
function M.setup()
    -- :ClaudeStatus - Show server status
    vim.api.nvim_create_user_command("ClaudeStatus", function()
        local status = server.get_status()
        if status.running then
            vim.notify(string.format("Claude IDE: Server running on port %d", status.port), vim.log.levels.INFO)

            -- Check lock file
            local lock_path = lockfile.get_lock_path(status.port)
            if vim.fn.filereadable(lock_path) == 1 then
                vim.notify("Lock file exists: " .. lock_path, vim.log.levels.INFO)
            else
                vim.notify("WARNING: Lock file missing: " .. lock_path, vim.log.levels.WARN)
            end
        else
            vim.notify("Claude IDE: Server not running", vim.log.levels.WARN)
        end
    end, { desc = "Show Claude IDE server status" })

    -- :ClaudeRestart - Restart server
    vim.api.nvim_create_user_command("ClaudeRestart", function()
        vim.notify("Restarting Claude IDE server...", vim.log.levels.INFO)
        server.stop()
        vim.wait(500) -- Brief pause

        local claude = require("plugins.claude")
        local success, err = claude.setup()
        if success then
            local status = server.get_status()
            vim.notify(string.format("Claude IDE restarted on port %d", status.port), vim.log.levels.INFO)
        else
            vim.notify("Failed to restart: " .. (err or "unknown error"), vim.log.levels.ERROR)
        end
    end, { desc = "Restart Claude IDE server" })

    -- :ClaudeCreateLock - Manually create lock file
    vim.api.nvim_create_user_command("ClaudeCreateLock", function()
        local status = server.get_status()
        if not status.running then
            vim.notify("Server not running", vim.log.levels.ERROR)
            return
        end

        local auth_token = lockfile.generate_auth_token()
        local success, err = lockfile.create(status.port, auth_token)
        if success then
            vim.notify(string.format("Created lock file for port %d", status.port), vim.log.levels.INFO)
        else
            vim.notify("Failed to create lock file: " .. (err or "unknown"), vim.log.levels.ERROR)
        end
    end, { desc = "Manually create Claude IDE lock file" })

    -- :ClaudeStop - Stop server
    vim.api.nvim_create_user_command("ClaudeStop", function()
        server.stop()
        vim.notify("Claude IDE server stopped", vim.log.levels.INFO)
    end, { desc = "Stop Claude IDE server" })
end

return M