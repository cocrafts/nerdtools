---@brief Navigation features for Claude IDE
---@module 'plugins.claude.navigation'

local M = {}

local logger = require("plugins.claude.logger")

--- Get the word under cursor
---@return string|nil
local function get_word_under_cursor()
    return vim.fn.expand("<cword>")
end

--- Get the full identifier under cursor (including dots for properties)
---@return string|nil
local function get_identifier_under_cursor()
    -- Save current position
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local col = pos[2] + 1  -- Lua uses 1-based indexing

    -- Find start of identifier
    local start_col = col
    while start_col > 1 do
        local char = line:sub(start_col - 1, start_col - 1)
        if not char:match("[%w_%.%:]") then
            break
        end
        start_col = start_col - 1
    end

    -- Find end of identifier
    local end_col = col
    while end_col <= #line do
        local char = line:sub(end_col, end_col)
        if not char:match("[%w_%.%:]") then
            break
        end
        end_col = end_col + 1
    end

    return line:sub(start_col, end_col - 1)
end

--- Use LSP to go to definition
---@return table|nil Definition location
function M.lsp_goto_definition()
    -- Check if LSP clients are available
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        logger.warn("No LSP clients available for buffer")
        return nil
    end

    local params = vim.lsp.util.make_position_params()

    local results = vim.lsp.buf_request_sync(0, "textDocument/definition", params, 2000)

    if not results then
        return nil
    end

    for client_id, result in pairs(results) do
        if result.result and #result.result > 0 then
            local def = result.result[1]

            -- Handle different response formats
            if def.targetUri or def.uri then
                local uri = def.targetUri or def.uri
                local range = def.targetSelectionRange or def.targetRange or def.range

                return {
                    uri = uri,
                    range = range,
                    file = vim.uri_to_fname(uri),
                    line = range.start.line + 1,  -- Convert to 1-based
                    col = range.start.character + 1
                }
            elseif def.uri then
                return {
                    uri = def.uri,
                    range = def.range,
                    file = vim.uri_to_fname(def.uri),
                    line = def.range.start.line + 1,
                    col = def.range.start.character + 1
                }
            end
        end
    end

    return nil
end

--- Find references using LSP
---@return table|nil List of references
function M.lsp_find_references()
    -- Check if LSP clients are available
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        logger.warn("No LSP clients available for buffer")
        return nil
    end

    local params = vim.lsp.util.make_position_params()
    params.context = { includeDeclaration = true }

    local results = vim.lsp.buf_request_sync(0, "textDocument/references", params, 2000)

    if not results then
        return nil
    end

    local references = {}

    for client_id, result in pairs(results) do
        if result.result then
            for _, ref in ipairs(result.result) do
                table.insert(references, {
                    uri = ref.uri,
                    range = ref.range,
                    file = vim.uri_to_fname(ref.uri),
                    line = ref.range.start.line + 1,
                    col = ref.range.start.character + 1,
                    text = M.get_line_text(vim.uri_to_fname(ref.uri), ref.range.start.line + 1)
                })
            end
        end
    end

    return #references > 0 and references or nil
end

--- Get text of a specific line in a file
---@param file string
---@param line number
---@return string|nil
function M.get_line_text(file, line)
    local buf = vim.fn.bufnr(file)

    if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
        local lines = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)
        return lines[1]
    else
        -- Read from file if not loaded
        local f = io.open(file, "r")
        if f then
            local current_line = 0
            for text in f:lines() do
                current_line = current_line + 1
                if current_line == line then
                    f:close()
                    return text
                end
            end
            f:close()
        end
    end

    return nil
end

--- Get hover information from LSP
---@return string|nil
function M.lsp_hover_info()
    local params = vim.lsp.util.make_position_params()

    local results = vim.lsp.buf_request_sync(0, "textDocument/hover", params, 1000)

    if not results then
        return nil
    end

    for client_id, result in pairs(results) do
        if result.result and result.result.contents then
            local contents = result.result.contents

            -- Handle different content formats
            if type(contents) == "string" then
                return contents
            elseif type(contents) == "table" then
                if contents.value then
                    return contents.value
                elseif contents.kind then
                    return contents.value
                else
                    -- Array of MarkedString
                    local parts = {}
                    for _, item in ipairs(contents) do
                        if type(item) == "string" then
                            table.insert(parts, item)
                        elseif item.value then
                            table.insert(parts, item.value)
                        end
                    end
                    return table.concat(parts, "\n")
                end
            end
        end
    end

    return nil
end

--- Rename symbol using LSP
---@param new_name string The new name for the symbol
---@return table|nil Rename edits
function M.lsp_rename_symbol(new_name)
    -- Check if LSP clients are available
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        logger.warn("No LSP clients available for buffer")
        return nil
    end

    -- Check if any client supports rename
    local supports_rename = false
    for _, client in ipairs(clients) do
        if client.server_capabilities.renameProvider then
            supports_rename = true
            break
        end
    end

    if not supports_rename then
        logger.warn("No LSP client supports rename")
        return nil
    end

    local params = vim.lsp.util.make_position_params()
    params.newName = new_name

    local results = vim.lsp.buf_request_sync(0, "textDocument/rename", params, 2000)

    if not results then
        return nil
    end

    local all_changes = {}

    for client_id, result in pairs(results) do
        if result.result then
            local changes = result.result.changes or result.result.documentChanges

            if changes then
                -- Handle workspace edit changes format
                if result.result.changes then
                    for uri, edits in pairs(result.result.changes) do
                        local file = vim.uri_to_fname(uri)
                        if not all_changes[file] then
                            all_changes[file] = {}
                        end
                        for _, edit in ipairs(edits) do
                            table.insert(all_changes[file], {
                                range = edit.range,
                                newText = edit.newText
                            })
                        end
                    end
                -- Handle documentChanges format
                elseif result.result.documentChanges then
                    for _, doc_change in ipairs(result.result.documentChanges) do
                        if doc_change.edits then
                            local file = vim.uri_to_fname(doc_change.textDocument.uri)
                            if not all_changes[file] then
                                all_changes[file] = {}
                            end
                            for _, edit in ipairs(doc_change.edits) do
                                table.insert(all_changes[file], {
                                    range = edit.range,
                                    newText = edit.newText
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return next(all_changes) and all_changes or nil
end

--- Go to definition and open the file
function M.goto_definition()
    local word = get_identifier_under_cursor()
    if not word then
        -- No word under cursor
        return
    end

    local def = M.lsp_goto_definition()

    if def then
        -- Log for debugging
        -- Found definition

        -- Open the file
        vim.cmd("edit " .. vim.fn.fnameescape(def.file))

        -- Jump to position
        vim.api.nvim_win_set_cursor(0, {def.line, def.col - 1})

        -- Center the screen
        vim.cmd("normal! zz")

        -- Jumped to definition

        return def
    else
        -- No definition found
        return nil
    end
end

--- Find all references and display in quickfix
function M.find_references()
    local word = get_identifier_under_cursor()
    if not word then
        -- No word under cursor
        return
    end

    local refs = M.lsp_find_references()

    if refs then
        -- Convert to quickfix items
        local qf_items = {}
        for _, ref in ipairs(refs) do
            table.insert(qf_items, {
                filename = ref.file,
                lnum = ref.line,
                col = ref.col,
                text = string.format("%s", ref.text or "")
            })
        end

        -- Set quickfix list
        vim.fn.setqflist(qf_items, 'r')
        vim.fn.setqflist({}, 'a', {title = string.format("References to '%s'", word)})

        -- Open quickfix
        vim.cmd("copen")

        -- Found references

        return refs
    else
        -- No references found
        return nil
    end
end

--- Rename symbol under cursor
---@param new_name string The new name for the symbol
---@return table|nil Result with information about the rename
function M.rename_symbol(new_name)
    local word = get_identifier_under_cursor()
    if not word then
        -- No symbol under cursor
        return nil
    end

    if not new_name or new_name == "" then
        -- New name cannot be empty
        return nil
    end

    -- Renaming symbol

    local changes = M.lsp_rename_symbol(new_name)

    if changes then
        -- Apply the changes
        vim.lsp.util.apply_workspace_edit({changes = changes}, "utf-8")

        -- Count total changes
        local file_count = 0
        local total_changes = 0
        for file, edits in pairs(changes) do
            file_count = file_count + 1
            total_changes = total_changes + #edits
        end

        -- Rename successful

        return {
            old_name = word,
            new_name = new_name,
            file_count = file_count,
            total_changes = total_changes,
            changes = changes
        }
    else
        -- Rename failed
        return nil
    end
end

--- Get symbol information for sending to Claude
function M.get_symbol_context()
    local word = get_identifier_under_cursor()
    if not word then
        return nil
    end

    local context = {
        symbol = word,
        current_file = vim.fn.expand("%:p"),
        current_line = vim.fn.line("."),
        definition = nil,
        references = {},
        hover_info = nil
    }

    -- Get definition
    local def = M.lsp_goto_definition()
    if def then
        context.definition = def

        -- Read some context around definition
        local buf = vim.fn.bufnr(def.file)
        if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
            local start_line = math.max(0, def.line - 6)
            local end_line = math.min(vim.api.nvim_buf_line_count(buf), def.line + 5)
            local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
            context.definition.context = table.concat(lines, "\n")
        end
    end

    -- Get references
    local refs = M.lsp_find_references()
    if refs then
        -- Limit to first 10 references for context
        for i = 1, math.min(10, #refs) do
            table.insert(context.references, refs[i])
        end
        context.total_references = #refs
    end

    -- Get hover info
    context.hover_info = M.lsp_hover_info()

    return context
end

--- Set up keymaps
function M.setup_keymaps()
    -- Go to definition
    vim.keymap.set("n", "gd", M.goto_definition, { desc = "Go to definition" })

    -- Find references
    vim.keymap.set("n", "gr", M.find_references, { desc = "Find references" })

    -- Send context to Claude
    vim.keymap.set("n", "<leader>cc", function()
        local context = M.get_symbol_context()
        if context then
            -- Format context for Claude
            local message = string.format(
                "Symbol: %s\nFile: %s:%d\n\n%s\n\nDefinition at %s:%d\n%s\n\nReferences: %d found",
                context.symbol,
                context.current_file,
                context.current_line,
                context.hover_info or "No type info available",
                context.definition and context.definition.file or "unknown",
                context.definition and context.definition.line or 0,
                context.definition and context.definition.context or "Not found",
                context.total_references or 0
            )

            -- TODO: Send this to Claude through the protocol
            vim.notify(message, vim.log.levels.INFO)

            -- Could also copy to clipboard
            vim.fn.setreg("+", message)
            -- Context copied
        end
    end, { desc = "Send symbol context to Claude" })
end

--- Test navigation functions (for debugging)
function M.test_navigation()
    print("\n=== Testing Navigation Functions ===\n")

    -- Check LSP status
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients > 0 then
        print("LSP clients active: " .. #clients)
        for _, client in ipairs(clients) do
            print("  - " .. client.name)
        end
    else
        print("No LSP clients active. Starting tsserver...")
        vim.cmd("LspStart")
        vim.wait(2000)  -- Wait for LSP to start
        clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients > 0 then
            print("LSP started successfully")
        else
            print("Failed to start LSP")
        end
    end

    print("\nTesting navigation on current file: " .. vim.api.nvim_buf_get_name(0))
    local pos = vim.api.nvim_win_get_cursor(0)
    print("Current position: Line " .. pos[1] .. ", Col " .. pos[2])

    -- Test goto definition
    print("\n1. Testing goto_definition...")
    local def = M.goto_definition()
    if def then
        print("   ✓ Definition found at " .. def.file .. ":" .. def.line)
    else
        print("   ✗ No definition found")
    end

    -- Test find references
    print("\n2. Testing find_references...")
    local refs = M.find_references()
    if refs and #refs > 0 then
        print("   ✓ Found " .. #refs .. " references")
        for i = 1, math.min(3, #refs) do
            print("     - " .. refs[i].file .. ":" .. refs[i].line)
        end
    else
        print("   ✗ No references found")
    end

    -- Test get symbol context
    print("\n3. Testing get_symbol_context...")
    local context = M.get_symbol_context()
    if context then
        print("   ✓ Context retrieved for symbol: " .. (context.symbol or "unknown"))
        if context.hover_info then
            print("   Type info: " .. context.hover_info:sub(1, 50) .. "...")
        end
    else
        print("   ✗ No context retrieved")
    end

    print("\n=== Navigation Test Complete ===\n")
end

return M