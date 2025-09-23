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

    -- :ClaudeLogLevel - Set log level
    vim.api.nvim_create_user_command("ClaudeLogLevel", function(opts)
        local logger = require("plugins.claude.logger")
        local level = opts.args:upper()

        local levels = {
            DEBUG = vim.log.levels.DEBUG,
            INFO = vim.log.levels.INFO,
            WARN = vim.log.levels.WARN,
            ERROR = vim.log.levels.ERROR,
        }

        if levels[level] then
            logger.set_level(levels[level])
            vim.notify(string.format("Claude IDE log level set to %s", level), vim.log.levels.INFO)
        else
            vim.notify("Invalid log level. Use: DEBUG, INFO, WARN, or ERROR", vim.log.levels.ERROR)
        end
    end, {
        desc = "Set Claude IDE log level (DEBUG, INFO, WARN, ERROR)",
        nargs = 1,
        complete = function()
            return { "DEBUG", "INFO", "WARN", "ERROR" }
        end
    })


    -- :ClaudeAdd - Send at_mention for current file or specified file
    vim.api.nvim_create_user_command("ClaudeAdd", function(opts)
        local file_path = opts.args ~= "" and opts.args or vim.api.nvim_buf_get_name(0)

        if file_path == "" then
            vim.notify("No file specified", vim.log.levels.ERROR)
            return
        end

        -- Get file content
        local lines = {}
        if vim.fn.filereadable(file_path) == 1 then
            lines = vim.fn.readfile(file_path)
        else
            vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
            return
        end

        local content = table.concat(lines, "\n")

        -- Send at_mentioned notification
        local params = {
            filePath = file_path,
            content = content,
        }

        -- Add line range if visual selection is active
        if opts.range and opts.range > 0 then
            params.lineStart = opts.line1 - 1  -- Convert to 0-indexed
            params.lineEnd = opts.line2 - 1
        end

        local success = server.send_at_mention(params)
        if success then
            vim.notify("Sent @mention for: " .. file_path, vim.log.levels.INFO)
        else
            vim.notify("Failed to send @mention", vim.log.levels.ERROR)
        end
    end, {
        desc = "Send at_mention notification for file to Claude",
        nargs = "?",
        range = true,
        complete = "file"
    })
end

return M