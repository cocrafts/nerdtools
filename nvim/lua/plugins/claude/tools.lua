---@brief MCP tools implementation for Claude IDE
---@module 'plugins.claude.tools'

local M = {}

local logger = require("plugins.claude.logger")

--- Get list of available tools
---@return table
function M.get_tool_list()
    return {
        -- closeAllDiffTabs tool (Claude Code sends this after accepting/rejecting)
        {
            name = "closeAllDiffTabs",
            description = "Close all diff tabs",
            inputSchema = {
                type = "object",
                properties = {},
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },
        -- openFile tool
        {
            name = "openFile",
            description = "Open a file in the editor and optionally select a range of text",
            inputSchema = {
                type = "object",
                properties = {
                    filePath = {
                        type = "string",
                        description = "Path to the file to open",
                    },
                    preview = {
                        type = "boolean",
                        description = "Whether to open the file in preview mode",
                        default = false,
                    },
                    startLine = {
                        type = "integer",
                        description = "Optional: Line number to start selection",
                    },
                    endLine = {
                        type = "integer",
                        description = "Optional: Line number to end selection",
                    },
                    startText = {
                        type = "string",
                        description = "Text pattern to find the start of the selection range",
                    },
                    endText = {
                        type = "string",
                        description = "Text pattern to find the end of the selection range",
                    },
                    selectToEndOfLine = {
                        type = "boolean",
                        description = "If true, selection will extend to end of line",
                        default = false,
                    },
                    makeFrontmost = {
                        type = "boolean",
                        description = "Whether to make the file the active editor tab",
                        default = true,
                    },
                },
                required = { "filePath" },
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },
        -- getCurrentSelection tool
        {
            name = "getCurrentSelection",
            description = "Get the current text selection in the active editor",
            inputSchema = {
                type = "object",
                properties = vim.empty_dict(),
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },
        -- getOpenEditors tool
        {
            name = "getOpenEditors",
            description = "Get information about currently open editors",
            inputSchema = {
                type = "object",
                properties = vim.empty_dict(),
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },
        -- getWorkspaceFolders tool
        {
            name = "getWorkspaceFolders",
            description = "Get all workspace folders currently open in the IDE",
            inputSchema = {
                type = "object",
                properties = vim.empty_dict(),
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },

        -- closeTab tool (for closing diff tabs when rejected)
        {
            name = "closeTab",
            description = "Close a tab by name",
            inputSchema = {
                type = "object",
                properties = {
                    tab_name = {
                        type = "string",
                        description = "Name of the tab to close",
                    },
                },
                required = { "tab_name" },
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },

        -- openDiff tool
        {
            name = "openDiff",
            description = "Open a diff view comparing old file content with new file content",
            inputSchema = {
                type = "object",
                properties = {
                    old_file_path = {
                        type = "string",
                        description = "Path to the old file to compare",
                    },
                    new_file_path = {
                        type = "string",
                        description = "Path to the new file to compare",
                    },
                    new_file_contents = {
                        type = "string",
                        description = "Contents for the new file version",
                    },
                    tab_name = {
                        type = "string",
                        description = "Name for the diff tab/view",
                    },
                },
                required = { "old_file_path", "new_file_path", "new_file_contents", "tab_name" },
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },

        -- getDiagnostics tool
        {
            name = "getDiagnostics",
            description = "Get language diagnostics from the editor",
            inputSchema = {
                type = "object",
                properties = {
                    uri = {
                        type = "string",
                        description = "File URI to get diagnostics for",
                    },
                },
                additionalProperties = false,
                ["$schema"] = "http://json-schema.org/draft-07/schema#",
            },
        },
    }
end

--- Execute a tool
---@param name string Tool name
---@param args table Tool arguments
---@return boolean success
---@return table|string result_or_error
function M.execute(name, args)
    logger.debug("Executing tool: " .. name)

    if name == "openFile" then
        return M.execute_open_file(args)
    elseif name == "openDiff" then
        return M.execute_open_diff(args)
    elseif name == "closeTab" then
        return M.execute_close_tab(args)
    elseif name == "closeAllDiffTabs" then
        return M.execute_close_all_diff_tabs(args)
    elseif name == "getCurrentSelection" then
        return M.execute_get_current_selection(args)
    elseif name == "getOpenEditors" then
        return M.execute_get_open_editors(args)
    elseif name == "getWorkspaceFolders" then
        return M.execute_get_workspace_folders(args)
    elseif name == "getDiagnostics" then
        return M.execute_get_diagnostics(args)
    else
        return false, "Unknown tool: " .. name
    end
end

--- Find main editor window (exclude sidebars, terminals, etc.)
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
        if
            is_suitable
            and (filetype == "neo-tree" or filetype == "NvimTree" or filetype == "oil" or filetype == "minifiles")
        then
            is_suitable = false
        end

        if is_suitable then
            return win
        end
    end

    return nil
end

--- Execute closeTab tool
---@param args table
---@return boolean success
---@return table result
function M.execute_close_tab(args)
    if not args.tab_name then
        return false, "Missing tab_name parameter"
    end

    vim.notify(string.format("[Claude IDE] CloseTab called with: %s", args.tab_name), vim.log.levels.WARN)
    logger.info(string.format("CloseTab called with: %s", args.tab_name))

    -- Try to close diff using the new function that handles tab names with markers
    local diffview = require("plugins.claude.diffview")
    local closed = diffview.close_diff_by_tab_name(args.tab_name)

    if closed then
        vim.notify(string.format("[Claude IDE] Successfully closed diff tab: %s", args.tab_name), vim.log.levels.INFO)
        logger.info(string.format("Successfully closed diff tab: %s", args.tab_name))
    else
        vim.notify(string.format("[Claude IDE] Diff not found or already closed: %s", args.tab_name), vim.log.levels.WARN)
        logger.debug(string.format("Diff not found or already closed: %s", args.tab_name))
    end

    return true,
        {
            content = {
                {
                    type = "text",
                    text = "TAB_CLOSED", -- Match claudecode.nvim's response
                },
            },
        }
end

--- Execute closeAllDiffTabs tool
---@param args table
---@return boolean success
---@return table result
function M.execute_close_all_diff_tabs(args)
    vim.notify("[Claude IDE] closeAllDiffTabs called", vim.log.levels.INFO)
    logger.info("closeAllDiffTabs called")

    -- Close all diff tabs more carefully
    local tabpages = vim.api.nvim_list_tabpages()

    -- Find a tab without diffs to keep open
    local safe_tab = nil
    for _, tabpage in ipairs(tabpages) do
        local has_diff = false
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            local buf = vim.api.nvim_win_get_buf(win)
            local buf_name = vim.api.nvim_buf_get_name(buf)
            if buf_name:match("%(Claude's suggestion%)") or
               vim.api.nvim_buf_get_option(buf, "diff") then
                has_diff = true
                break
            end
        end
        if not has_diff then
            safe_tab = tabpage
            break
        end
    end

    -- Go to safe tab or first tab, then close all others
    if safe_tab then
        vim.api.nvim_set_current_tabpage(safe_tab)
    else
        vim.cmd("tabnext 1")
    end

    if #tabpages > 1 then
        vim.cmd("tabonly")
    end

    local diffview = require("plugins.claude.diffview")

    -- Clear all active diffs from tracking
    local active_diffs = diffview.get_active_diffs and diffview.get_active_diffs() or {}
    for tab_name, diff in pairs(active_diffs) do
        if diff.temp_file then
            vim.fn.delete(diff.temp_file)
        end
        active_diffs[tab_name] = nil
    end

    -- Now clean up any lingering suggestion buffers
    local buffers_deleted = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local buf_name = vim.api.nvim_buf_get_name(buf)
            -- Match the exact format: "filename (Claude's suggestion)" or temp files
            if buf_name:match("%(Claude's suggestion%)") or
               buf_name:match("claude_diff") or
               (buf_name:match("/tmp/") and buf_name:match("claude")) then
                pcall(vim.cmd, string.format("silent! bwipeout! %d", buf))
                buffers_deleted = buffers_deleted + 1
            end
        end
    end

    -- Turn off diff mode in any remaining windows
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "diff") then
            vim.api.nvim_win_call(win, function()
                vim.cmd("diffoff")
            end)
        end
    end

    vim.notify(string.format("[Claude IDE] Closed %d windows and deleted %d buffers", windows_closed, buffers_deleted), vim.log.levels.INFO)

    return true,
        {
            content = {
                {
                    type = "text",
                    text = "ALL_DIFF_TABS_CLOSED",
                },
            },
        }
end

--- Execute openDiff tool
---@param args table
---@return boolean success
---@return table result
function M.execute_open_diff(args)
    -- Validate required parameters
    if not args.old_file_path or not args.new_file_path or not args.new_file_contents or not args.tab_name then
        return false, "Missing required parameters for openDiff"
    end

    local diffview = require("plugins.claude.diffview")
    local success, err =
        diffview.open_diff(args.old_file_path, args.new_file_path, args.new_file_contents, args.tab_name)

    if success then
        return true,
            {
                content = {
                    {
                        type = "text",
                        text = string.format("Diff opened for %s", args.old_file_path),
                    },
                },
            }
    else
        return false, err or "Failed to open diff"
    end
end

--- Execute openFile tool
---@param args table
---@return boolean success
---@return table result
function M.execute_open_file(args)
    local file_path = vim.fn.expand(args.filePath)

    if vim.fn.filereadable(file_path) == 0 then
        return false, { error = "File not found: " .. file_path }
    end

    local make_frontmost = args.makeFrontmost ~= false
    local message = "Opened file: " .. file_path
    local success = true

    -- Execute synchronously to ensure file is opened before returning
    local ok, err = pcall(function()
        -- Find or create suitable window
        local target_win = find_main_editor_window()

        if target_win then
            vim.api.nvim_win_call(target_win, function()
                vim.cmd("edit " .. vim.fn.fnameescape(file_path))
            end)
            if make_frontmost then
                vim.api.nvim_set_current_win(target_win)
            end
        else
            -- Create new window
            vim.cmd("edit " .. vim.fn.fnameescape(file_path))
        end

        -- Handle line-based selection
        if args.startLine then
            local start_line = args.startLine
            local end_line = args.endLine or start_line

            vim.api.nvim_win_set_cursor(0, { start_line, 0 })

            if end_line > start_line then
                -- Create visual selection
                vim.cmd("normal! V")
                vim.cmd("normal! " .. end_line .. "G")
                message = string.format("Opened file and selected lines %d-%d", start_line, end_line)
            end
        end

        -- Handle text pattern selection
        if args.startText then
            local buf = vim.api.nvim_get_current_buf()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

            for line_idx, line in ipairs(lines) do
                local col_idx = string.find(line, args.startText, 1, true)
                if col_idx then
                    vim.api.nvim_win_set_cursor(0, { line_idx, col_idx - 1 })

                    if args.endText then
                        -- Find end text
                        for end_idx = line_idx, #lines do
                            local end_col = string.find(lines[end_idx], args.endText, 1, true)
                            if end_col then
                                -- Create selection
                                vim.cmd("normal! v")
                                vim.api.nvim_win_set_cursor(0, { end_idx, end_col + #args.endText - 2 })
                                message = string.format('Selected from "%s" to "%s"', args.startText, args.endText)
                                break
                            end
                        end
                    else
                        -- Select just the start text
                        vim.cmd("normal! v")
                        vim.api.nvim_win_set_cursor(0, { line_idx, col_idx + #args.startText - 2 })
                        message = 'Selected "' .. args.startText .. '"'
                    end

                    break
                end
            end
        end

        logger.info(message)
    end)

    if not ok then
        return false, { error = "Failed to open file: " .. tostring(err) }
    end

    -- Get buffer info
    local buf = vim.fn.bufnr(file_path)
    if buf == -1 then
        -- File was opened, create simplified success response
        return true, {
            success = true,
            message = message,
        }
    end

    -- Return detailed info
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")

    return true, {
        success = true,
        message = message,
        content = content,
        filePath = file_path,
    }
end

--- Execute getCurrentSelection tool
---@param args table
---@return boolean success
---@return table result
function M.execute_get_current_selection(args)
    local mode = vim.fn.mode()

    if not mode:match("[vV\22]") then
        -- No selection
        return true, {
            text = "",
            isEmpty = true,
        }
    end

    -- Get selection
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_line = start_pos[2]
    local end_line = end_pos[2]
    local start_col = start_pos[3]
    local end_col = end_pos[3]

    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local text = table.concat(lines, "\n")

    local file_path = vim.api.nvim_buf_get_name(0)

    return true,
        {
            text = text,
            filePath = file_path,
            selection = {
                start = { line = start_line - 1, character = start_col - 1 },
                ["end"] = { line = end_line - 1, character = end_col - 1 },
                isEmpty = false,
            },
        }
end

--- Execute getOpenEditors tool
---@param args table
---@return boolean success
---@return table result
function M.execute_get_open_editors(args)
    local tabs = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" then
                local modified = vim.api.nvim_buf_get_option(buf, "modified")
                local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
                local current = vim.api.nvim_get_current_buf() == buf

                table.insert(tabs, {
                    uri = "file://" .. name,
                    isActive = current,
                    label = vim.fn.fnamemodify(name, ":t"),
                    languageId = filetype,
                    isDirty = modified,
                })
            end
        end
    end

    return true, {
        editors = tabs,
    }
end

--- Execute getWorkspaceFolders tool
---@param args table
---@return boolean success
---@return table result
function M.execute_get_workspace_folders(args)
    local folders = {}
    local root_path = vim.fn.getcwd()

    -- Add current working directory
    table.insert(folders, {
        name = vim.fn.fnamemodify(root_path, ":t"),
        uri = "file://" .. root_path,
        path = root_path,
    })

    -- Add git root if different
    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if vim.v.shell_error == 0 and git_root ~= "" and git_root ~= root_path then
        table.insert(folders, {
            name = vim.fn.fnamemodify(git_root, ":t"),
            uri = "file://" .. git_root,
            path = git_root,
        })
    end

    return true, {
        folders = folders,
    }
end

--- Execute getDiagnostics tool
---@param args table
---@return boolean success
---@return table result
function M.execute_get_diagnostics(args)
    -- Check if diagnostics are available
    if not vim.diagnostic or not vim.diagnostic.get then
        return false, "Diagnostics not available"
    end

    local diagnostics
    local bufnr_to_check = nil

    if args.uri then
        -- Get diagnostics for specific file
        local file_path = args.uri:gsub("^file://", "")

        -- Try different methods to find the buffer
        bufnr_to_check = vim.fn.bufnr(file_path)

        -- If not found with full path, try expanding it
        if bufnr_to_check == -1 then
            file_path = vim.fn.expand(file_path)
            bufnr_to_check = vim.fn.bufnr(file_path)
        end

        -- If still not found, check all buffers for a matching name
        if bufnr_to_check == -1 then
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                local buf_name = vim.api.nvim_buf_get_name(buf)
                if buf_name == file_path or buf_name:match(file_path .. "$") then
                    bufnr_to_check = buf
                    break
                end
            end
        end

        if bufnr_to_check == -1 or not vim.api.nvim_buf_is_valid(bufnr_to_check) then
            -- File not open, return empty content
            return true, {
                content = {},
            }
        end

        diagnostics = vim.diagnostic.get(bufnr_to_check)
    else
        -- Get all diagnostics
        diagnostics = vim.diagnostic.get(nil)
    end

    -- Format diagnostics in MCP content format (matching claudecode.nvim)
    local formatted_content = {}
    for _, diag in ipairs(diagnostics) do
        local file_path = vim.api.nvim_buf_get_name(diag.bufnr)
        if file_path and file_path ~= "" then
            table.insert(formatted_content, {
                type = "text",
                text = vim.json.encode({
                    filePath = file_path,
                    -- Convert to 1-indexed for Claude (Neovim uses 0-indexed)
                    line = diag.lnum + 1,
                    character = diag.col + 1,
                    severity = diag.severity,
                    message = diag.message,
                    source = diag.source,
                }),
            })
        end
    end

    return true, {
        content = formatted_content,
    }
end

return M

