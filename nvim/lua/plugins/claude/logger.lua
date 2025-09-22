---@brief Logger module for Claude IDE
---@module 'plugins.claude.logger'

local M = {}

-- Log levels
local LEVELS = {
    DEBUG = vim.log.levels.DEBUG,
    INFO = vim.log.levels.INFO,
    WARN = vim.log.levels.WARN,
    ERROR = vim.log.levels.ERROR,
}

-- Current log level
local current_level = LEVELS.INFO

--- Setup logger
---@param level number|nil
function M.setup(level)
    current_level = level or LEVELS.INFO
end

--- Log message
---@param level number
---@param message string
---@param ... any Additional arguments
local function log(level, message, ...)
    if level < current_level then
        return
    end

    local prefix = "[Claude IDE] "
    local full_message = prefix .. message

    if select("#", ...) > 0 then
        full_message = full_message .. " " .. table.concat({ ... }, " ")
    end

    vim.schedule(function()
        vim.notify(full_message, level)
    end)
end

--- Debug log
---@param message string
---@param ... any
function M.debug(message, ...)
    log(LEVELS.DEBUG, message, ...)
end

--- Info log
---@param message string
---@param ... any
function M.info(message, ...)
    log(LEVELS.INFO, message, ...)
end

--- Warning log
---@param message string
---@param ... any
function M.warn(message, ...)
    log(LEVELS.WARN, message, ...)
end

--- Error log
---@param message string
---@param ... any
function M.error(message, ...)
    log(LEVELS.ERROR, message, ...)
end

--- Set log level
---@param level number|string
function M.set_level(level)
    if type(level) == "string" then
        level = LEVELS[level:upper()]
    end
    current_level = level or LEVELS.INFO
end

--- Get current log level
---@return number
function M.get_level()
    return current_level
end

return M