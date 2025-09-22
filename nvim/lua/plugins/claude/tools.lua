---@brief MCP tools implementation for Claude IDE
---@module 'plugins.claude.tools'

local M = {}

local logger = require("plugins.claude.logger")

--- Get list of available tools
---@return table
function M.get_tool_list()
    return {
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
            message = message
        }
    end

    -- Return detailed info
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")

    return true, {
        success = true,
        message = message,
        content = content,
        filePath = file_path
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
            isEmpty = true
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

    return true, {
        text = text,
        filePath = file_path,
        selection = {
            start = { line = start_line - 1, character = start_col - 1 },
            ["end"] = { line = end_line - 1, character = end_col - 1 },
            isEmpty = false
        }
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
        editors = tabs
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
        folders = folders
    }
end

--- Execute getDiagnostics tool
---@param args table
---@return boolean success
---@return table result
function M.execute_get_diagnostics(args)
    local diagnostics_by_file = {}

    if args.uri then
        -- Get diagnostics for specific file
        local file_path = args.uri:gsub("^file://", "")
        local bufnr = vim.fn.bufnr(file_path)

        if bufnr ~= -1 then
            local diagnostics = vim.diagnostic.get(bufnr)
            local formatted = {}

            for _, diag in ipairs(diagnostics) do
                table.insert(formatted, {
                    message = diag.message,
                    severity = vim.diagnostic.severity[diag.severity],
                    range = {
                        start = { line = diag.lnum, character = diag.col },
                        ["end"] = { line = diag.end_lnum or diag.lnum, character = diag.end_col or diag.col },
                    },
                    source = diag.source,
                })
            end

            diagnostics_by_file[file_path] = {
                uri = args.uri,
                diagnostics = formatted,
            }
        end
    else
        -- Get all diagnostics
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
                local file_path = vim.api.nvim_buf_get_name(buf)
                if file_path ~= "" then
                    local diagnostics = vim.diagnostic.get(buf)
                    if #diagnostics > 0 then
                        local formatted = {}

                        for _, diag in ipairs(diagnostics) do
                            table.insert(formatted, {
                                message = diag.message,
                                severity = vim.diagnostic.severity[diag.severity],
                                range = {
                                    start = { line = diag.lnum, character = diag.col },
                                    ["end"] = { line = diag.end_lnum or diag.lnum, character = diag.end_col or diag.col },
                                },
                                source = diag.source,
                            })
                        end

                        table.insert(diagnostics_by_file, {
                            uri = "file://" .. file_path,
                            diagnostics = formatted,
                        })
                    end
                end
            end
        end
    end

    -- Return diagnostics in the expected format
    if #diagnostics_by_file > 0 then
        return true, diagnostics_by_file[1] -- Return the first file's diagnostics
    else
        return true, {
            uri = args.uri or "",
            diagnostics = {}
        }
    end
end

return M