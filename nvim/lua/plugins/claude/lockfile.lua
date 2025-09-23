---@brief Lock file management for Claude IDE discovery
---@module 'plugins.claude.lockfile'

local M = {}

local logger = require("plugins.claude.logger")

--- Get lock directory path
---@return string
function M.get_lock_dir()
    local claude_config_dir = os.getenv("CLAUDE_CONFIG_DIR")
    if claude_config_dir and claude_config_dir ~= "" then
        return vim.fn.expand(claude_config_dir .. "/ide")
    else
        return vim.fn.expand("~/.claude/ide")
    end
end

--- Get lock file path for a specific port
---@param port number
---@return string
function M.get_lock_path(port)
    return M.get_lock_dir() .. "/" .. port .. ".lock"
end

--- Generate random UUID for authentication
---@return string
function M.generate_auth_token()
    -- Initialize random seed
    math.randomseed(os.time() + vim.fn.getpid())

    -- Generate UUID v4 format
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local uuid = template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)

    return uuid
end

--- Get workspace folders
---@return table
local function get_workspace_folders()
    local folders = {}

    -- Add current working directory
    table.insert(folders, vim.fn.getcwd())

    -- Add git root if different
    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if vim.v.shell_error == 0 and git_root ~= "" and git_root ~= vim.fn.getcwd() then
        table.insert(folders, git_root)
    end

    -- Add LSP workspace folders
    local clients = vim.lsp.get_active_clients()
    for _, client in pairs(clients) do
        if client.config and client.config.workspace_folders then
            for _, ws in ipairs(client.config.workspace_folders) do
                local path = ws.uri:gsub("^file://", "")
                local exists = false
                for _, folder in ipairs(folders) do
                    if folder == path then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(folders, path)
                end
            end
        end
    end

    return folders
end

--- Create lock file
---@param port number
---@param auth_token string
---@return boolean success
---@return string|nil error_message
function M.create(port, auth_token)
    if not port or type(port) ~= "number" then
        return false, "Invalid port number"
    end

    if not auth_token or type(auth_token) ~= "string" then
        return false, "Invalid auth token"
    end

    local lock_dir = M.get_lock_dir()

    -- Create directory
    vim.fn.mkdir(lock_dir, "p")

    local lock_path = lock_dir .. "/" .. port .. ".lock"

    -- Prepare lock file content
    local lock_content = {
        pid = vim.fn.getpid(),
        workspaceFolders = get_workspace_folders(),
        ideName = "Neovim",
        transport = "ws",
        authToken = auth_token,
    }

    -- Write lock file
    local json = vim.json.encode(lock_content)
    local file = io.open(lock_path, "w")
    if not file then
        return false, "Failed to create lock file: " .. lock_path
    end

    file:write(json)
    file:close()

    -- Created lock file

    return true
end

--- Read lock file content
---@param port number
---@return table|nil lock_data
function M.read(port)
    if not port or type(port) ~= "number" then
        return nil
    end

    local lock_path = M.get_lock_path(port)

    if vim.fn.filereadable(lock_path) == 0 then
        return nil
    end

    local file = io.open(lock_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()

    local ok, data = pcall(vim.json.decode, content)
    if not ok then
        -- Failed to parse lock file
        return nil
    end

    return data
end

--- Remove lock file (alias for delete)
---@param port number
---@return boolean success
---@return string|nil error_message
function M.remove(port)
    if not port or type(port) ~= "number" then
        return false, "Invalid port number"
    end

    local lock_dir = M.get_lock_dir()
    local lock_path = lock_dir .. "/" .. port .. ".lock"

    if vim.fn.filereadable(lock_path) == 0 then
        return true -- Already removed
    end

    local ok, err = os.remove(lock_path)
    if not ok then
        return false, "Failed to remove lock file: " .. (err or "unknown error")
    end

    -- Removed lock file

    return true
end

--- Delete lock file (alias for remove)
M.delete = M.remove

--- Update lock file
---@param port number
---@param auth_token string
---@return boolean success
---@return string|nil error_message
function M.update(port, auth_token)
    M.remove(port)
    return M.create(port, auth_token)
end

--- Read lock file
---@param port number
---@return table|nil lock_data
function M.read(port)
    if not port or type(port) ~= "number" then
        return nil
    end

    local lock_dir = M.get_lock_dir()
    local lock_path = lock_dir .. "/" .. port .. ".lock"

    if vim.fn.filereadable(lock_path) == 0 then
        return nil
    end

    local file = io.open(lock_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*all")
    file:close()

    local ok, lock_data = pcall(vim.json.decode, content)
    if not ok then
        return nil
    end

    return lock_data
end

return M