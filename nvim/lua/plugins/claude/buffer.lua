---@brief Enhanced buffer content management for Claude IDE
---@module 'plugins.claude.buffer'

local M = {}

local logger = require("plugins.claude.logger")
local server = nil -- Will be set during setup

-- Buffer tracking state
local state = {
    tracked_buffers = {}, -- Track buffer versions and content
    debounce_timers = {}, -- Per-buffer debounce timers
    debounce_ms = 300, -- Debounce delay for buffer changes
    batch_timer = nil, -- Timer for batching multiple buffer updates
    pending_updates = {}, -- Queue of pending buffer updates
}

--- Get buffer content
---@param bufnr number|nil Buffer number (nil for current)
---@return table|nil Buffer information
function M.get_buffer_content(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    local modified = vim.api.nvim_buf_get_option(bufnr, "modified")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    return {
        buffer = bufnr,
        filepath = filepath,
        filetype = filetype,
        modified = modified,
        content = table.concat(lines, "\n"),
        lineCount = #lines,
        version = vim.b[bufnr].changedtick or 0,
    }
end

--- Get all open buffers
---@return table Array of buffer information
function M.get_all_buffers()
    local buffers = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            -- Only include buffers with actual files
            if name ~= "" and vim.bo[buf].buftype == "" then
                local info = M.get_buffer_content(buf)
                if info then
                    table.insert(buffers, info)
                end
            end
        end
    end

    return buffers
end

--- Check if buffer content has changed
---@param bufnr number Buffer number
---@return boolean
local function has_buffer_changed(bufnr)
    local current_tick = vim.b[bufnr].changedtick or 0
    local last_tick = state.tracked_buffers[bufnr] or -1
    return current_tick ~= last_tick
end

--- Send buffer update notification
---@param bufnr number Buffer number
local function send_buffer_update(bufnr)
    if not server or not server.is_connected or not server.is_connected() then
        return
    end

    local info = M.get_buffer_content(bufnr)
    if not info or info.filepath == "" then
        return
    end

    -- Update tracked version
    state.tracked_buffers[bufnr] = info.version

    -- Send notification
    server.broadcast({
        jsonrpc = "2.0",
        method = "notifications/bufferContent",
        params = {
            uri = "file://" .. info.filepath,
            content = info.content,
            version = info.version,
            languageId = info.filetype,
        },
    })

    -- Buffer updated
end

--- Debounced buffer update
---@param bufnr number Buffer number
local function debounce_buffer_update(bufnr)
    -- Cancel existing timer for this buffer
    if state.debounce_timers[bufnr] then
        vim.loop.timer_stop(state.debounce_timers[bufnr])
        state.debounce_timers[bufnr] = nil
    end

    -- Create new debounce timer
    state.debounce_timers[bufnr] = vim.defer_fn(function()
        if has_buffer_changed(bufnr) then
            send_buffer_update(bufnr)
        end
        state.debounce_timers[bufnr] = nil
    end, state.debounce_ms)
end

--- Batch multiple buffer updates
local function batch_buffer_updates()
    if state.batch_timer then
        vim.loop.timer_stop(state.batch_timer)
    end

    state.batch_timer = vim.defer_fn(function()
        for bufnr, _ in pairs(state.pending_updates) do
            if vim.api.nvim_buf_is_valid(bufnr) then
                send_buffer_update(bufnr)
            end
        end
        state.pending_updates = {}
        state.batch_timer = nil
    end, 100) -- 100ms batch window
end

--- Handle buffer change event
---@param bufnr number Buffer number
local function on_buffer_changed(bufnr)
    -- Skip special buffers
    if vim.bo[bufnr].buftype ~= "" then
        return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then
        return
    end

    -- Debounce the update
    debounce_buffer_update(bufnr)
end

--- Handle buffer open event
---@param bufnr number Buffer number
local function on_buffer_open(bufnr)
    if not server or not server.is_connected or not server.is_connected() then
        return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" or vim.bo[bufnr].buftype ~= "" then
        return
    end

    -- Track this buffer
    state.tracked_buffers[bufnr] = vim.b[bufnr].changedtick or 0

    -- Send open notification
    server.broadcast({
        jsonrpc = "2.0",
        method = "notifications/bufferOpened",
        params = {
            uri = "file://" .. filepath,
            languageId = vim.bo[bufnr].filetype,
        },
    })

    -- Buffer opened
end

--- Handle buffer close event
---@param bufnr number Buffer number
local function on_buffer_close(bufnr)
    if not server or not server.is_connected or not server.is_connected() then
        return
    end

    -- Clean up tracking
    state.tracked_buffers[bufnr] = nil
    if state.debounce_timers[bufnr] then
        vim.loop.timer_stop(state.debounce_timers[bufnr])
        state.debounce_timers[bufnr] = nil
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then
        return
    end

    -- Send close notification
    server.broadcast({
        jsonrpc = "2.0",
        method = "notifications/bufferClosed",
        params = {
            uri = "file://" .. filepath,
        },
    })

    -- Buffer closed
end

--- Setup buffer tracking
---@param srv table Server instance
function M.setup_tracking(srv)
    server = srv

    local group = vim.api.nvim_create_augroup("ClaudeBufferTracking", { clear = true })

    -- Track buffer content changes with smart debouncing
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(args)
            on_buffer_changed(args.buf)
        end,
        desc = "Track buffer changes for Claude",
    })

    -- Track buffer open
    vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd" }, {
        group = group,
        callback = function(args)
            on_buffer_open(args.buf)
        end,
        desc = "Track buffer open for Claude",
    })

    -- Track buffer close
    vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
        group = group,
        callback = function(args)
            on_buffer_close(args.buf)
        end,
        desc = "Track buffer close for Claude",
    })

    -- Send initial buffer states
    vim.schedule(function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
                local name = vim.api.nvim_buf_get_name(buf)
                if name ~= "" and vim.bo[buf].buftype == "" then
                    state.tracked_buffers[buf] = vim.b[buf].changedtick or 0
                end
            end
        end
    end)

    -- Buffer tracking initialized
end

--- Stop buffer tracking
function M.stop_tracking()
    -- Clean up all timers
    for _, timer in pairs(state.debounce_timers) do
        if timer then
            vim.loop.timer_stop(timer)
        end
    end
    state.debounce_timers = {}

    if state.batch_timer then
        vim.loop.timer_stop(state.batch_timer)
        state.batch_timer = nil
    end

    state.tracked_buffers = {}
    state.pending_updates = {}
    server = nil

    -- Buffer tracking stopped
end

return M

