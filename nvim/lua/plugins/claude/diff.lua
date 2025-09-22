---@brief Diff module for Claude IDE
---@module 'plugins.claude.diff'

local M = {}

local logger = require("plugins.claude.logger")

-- Active diff tracking
local active_diffs = {}

--- Find a suitable main editor window
---@return number|nil
local function find_main_editor_window()
    local windows = vim.api.nvim_list_wins()

    for _, win in ipairs(windows) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
        local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
        local win_config = vim.api.nvim_win_get_config(win)

        local is_suitable = true

        -- Skip floating windows
        if win_config.relative and win_config.relative ~= "" then
            is_suitable = false
        end

        -- Skip special buffer types
        if is_suitable and (buftype == "terminal" or buftype == "nofile" or buftype == "prompt") then
            is_suitable = false
        end

        -- Skip known sidebar filetypes
        if is_suitable and (
            filetype == "neo-tree" or
            filetype == "NvimTree" or
            filetype == "oil" or
            filetype == "minifiles"
        ) then
            is_suitable = false
        end

        if is_suitable then
            return win
        end
    end

    return nil
end

--- Create a diff view
---@param old_file_path string
---@param new_file_path string
---@param new_file_contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.open_diff(old_file_path, new_file_path, new_file_contents, tab_name)
    -- Check if file exists
    local old_file_exists = vim.fn.filereadable(old_file_path) == 1

    if not old_file_exists then
        -- New file creation
        return M.open_diff_new_file(new_file_path, new_file_contents, tab_name)
    end

    -- Check if buffer is dirty
    local buf = vim.fn.bufnr(old_file_path)
    if buf ~= -1 and vim.api.nvim_buf_get_option(buf, "modified") then
        return false, "File has unsaved changes: " .. old_file_path
    end

    -- Store active diff info
    active_diffs[tab_name] = {
        old_file = old_file_path,
        new_file = new_file_path,
        contents = new_file_contents,
    }

    -- Find or create suitable window
    local target_win = find_main_editor_window()
    if not target_win then
        vim.cmd("tabnew")
        target_win = vim.api.nvim_get_current_win()
    else
        vim.api.nvim_set_current_win(target_win)
    end

    -- Set diff filler characters globally to use diagonal lines
    vim.opt.fillchars:append("diff:╱")

    -- Open original file
    vim.cmd("edit " .. vim.fn.fnameescape(old_file_path))
    local old_buf = vim.api.nvim_get_current_buf()
    vim.cmd("diffthis")

    -- Create vertical split for new content
    vim.cmd("vnew")
    local new_buf = vim.api.nvim_get_current_buf()

    -- Set up the new buffer with proposed changes
    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, vim.split(new_file_contents, "\n"))
    vim.api.nvim_buf_set_name(new_buf, new_file_path .. " (Claude's suggestion)")

    -- Copy filetype for syntax highlighting
    local old_ft = vim.api.nvim_buf_get_option(old_buf, "filetype")
    if old_ft and old_ft ~= "" then
        vim.api.nvim_buf_set_option(new_buf, "filetype", old_ft)
    end

    -- Make it a scratch buffer
    vim.api.nvim_buf_set_option(new_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(new_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(new_buf, "bufhidden", "wipe")

    vim.cmd("diffthis")

    -- Equal window sizes
    vim.cmd("wincmd =")

    -- Add keymaps for accepting/rejecting
    local opts = { buffer = new_buf, silent = true }
    vim.keymap.set("n", "<leader>da", function() M.accept_diff(tab_name) end,
        vim.tbl_extend("force", opts, { desc = "Accept Claude's changes" }))
    vim.keymap.set("n", "<leader>dr", function() M.reject_diff(tab_name) end,
        vim.tbl_extend("force", opts, { desc = "Reject Claude's changes" }))

    -- Notify user
    vim.notify(string.format(
        "[Claude IDE] Diff opened. Accept: <leader>da or :w | Reject: <leader>dr or :q",
        tab_name
    ), vim.log.levels.INFO)

    return true
end

--- Create diff for a new file
---@param file_path string
---@param contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.open_diff_new_file(file_path, contents, tab_name)
    -- Store active diff info
    active_diffs[tab_name] = {
        old_file = nil,
        new_file = file_path,
        contents = contents,
        is_new = true,
    }

    -- Find or create suitable window
    local target_win = find_main_editor_window()
    if not target_win then
        vim.cmd("tabnew")
        target_win = vim.api.nvim_get_current_win()
    else
        vim.api.nvim_set_current_win(target_win)
    end

    -- Create new buffer with proposed content
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))
    vim.api.nvim_buf_set_name(buf, file_path .. " (New file by Claude)")

    -- Set appropriate filetype based on extension
    local ext = file_path:match("%.([^%.]+)$")
    if ext then
        local ft = vim.filetype.match({ filename = file_path })
        if ft then
            vim.api.nvim_buf_set_option(buf, "filetype", ft)
        end
    end

    -- Add keymaps
    local opts = { buffer = buf, silent = true }
    vim.keymap.set("n", "<leader>da", function() M.accept_new_file(tab_name) end,
        vim.tbl_extend("force", opts, { desc = "Accept new file" }))
    vim.keymap.set("n", "<leader>dr", function() M.reject_diff(tab_name) end,
        vim.tbl_extend("force", opts, { desc = "Reject new file" }))

    vim.notify(string.format(
        "[Claude IDE] New file: %s. Accept: <leader>da | Reject: <leader>dr",
        file_path
    ), vim.log.levels.INFO)

    return true
end

--- Accept diff changes
---@param tab_name string
function M.accept_diff(tab_name)
    local diff = active_diffs[tab_name]
    if not diff then
        vim.notify("[Claude IDE] No active diff found", vim.log.levels.WARN)
        return
    end

    if diff.is_new then
        return M.accept_new_file(tab_name)
    end

    -- Write the changes to the original file
    vim.cmd("write! " .. vim.fn.fnameescape(diff.old_file))

    -- Close the diff
    vim.cmd("diffoff!")
    vim.cmd("only")

    active_diffs[tab_name] = nil
    vim.notify("[Claude IDE] Changes accepted and saved", vim.log.levels.INFO)
end

--- Accept new file creation
---@param tab_name string
function M.accept_new_file(tab_name)
    local diff = active_diffs[tab_name]
    if not diff or not diff.is_new then
        vim.notify("[Claude IDE] No new file diff found", vim.log.levels.WARN)
        return
    end

    -- Save the new file
    vim.cmd("write " .. vim.fn.fnameescape(diff.new_file))

    active_diffs[tab_name] = nil
    vim.notify("[Claude IDE] New file created: " .. diff.new_file, vim.log.levels.INFO)
end

--- Reject diff changes
---@param tab_name string
function M.reject_diff(tab_name)
    local diff = active_diffs[tab_name]
    if not diff then
        vim.notify("[Claude IDE] No active diff found", vim.log.levels.WARN)
        return
    end

    -- Close without saving
    vim.cmd("diffoff!")
    vim.cmd("bdelete!")

    if not diff.is_new and diff.old_file then
        -- Return to original file
        vim.cmd("edit " .. vim.fn.fnameescape(diff.old_file))
    end

    active_diffs[tab_name] = nil
    vim.notify("[Claude IDE] Changes rejected", vim.log.levels.INFO)
end

return M