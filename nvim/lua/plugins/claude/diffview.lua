---@brief Diffview integration for Claude IDE
---@module 'plugins.claude.diffview'

local M = {}

local logger = require("plugins.claude.logger")
local protocol = require("plugins.claude.protocol")

-- Track active diffs
local active_diffs = {}

-- Autocmd group for diff operations
local autocmd_group = vim.api.nvim_create_augroup("ClaudeIDEDiff", { clear = true })

-- Note: Removed notify_diff_decision as we now use protocol.send_diff_response
-- which sends a proper JSON-RPC response instead of a notification

--- Check if diffview.nvim is available
---@return boolean
local function has_diffview()
	local ok, _ = pcall(require, "diffview")
	return ok
end

--- Create a temporary file with content
---@param content string
---@param extension string|nil
---@return string filepath
local function create_temp_file(content, extension)
	local tmp_dir = vim.fn.tempname()
	vim.fn.mkdir(tmp_dir, "p")

	local filename = string.format(
		"%s/claude_diff_%s%s",
		tmp_dir,
		vim.fn.strftime("%Y%m%d_%H%M%S"),
		extension and ("." .. extension) or ""
	)

	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
	end

	return filename
end

--- Get file extension from path
---@param filepath string
---@return string|nil
local function get_extension(filepath)
	return filepath:match("%.([^%.]+)$")
end

--- Open diff using diffview.nvim
---@param old_file_path string
---@param new_file_path string
---@param new_file_contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.open_diffview(old_file_path, new_file_path, new_file_contents, tab_name)
	if not has_diffview() then
		logger.warn("diffview.nvim not available, falling back to native diff")
		return false, "diffview.nvim not available"
	end

	local diffview = require("diffview")
	local lib = require("diffview.lib")

	-- Check if old file exists
	local old_file_exists = vim.fn.filereadable(old_file_path) == 1

	-- Create temp file with new contents
	local ext = get_extension(new_file_path or old_file_path)
	local temp_file = create_temp_file(new_file_contents, ext)

	-- Store diff info with callback
	active_diffs[tab_name] = {
		old_file = old_file_path,
		new_file = new_file_path,
		temp_file = temp_file,
		contents = new_file_contents,
		is_new = not old_file_exists,
		status = "pending",
		new_buffer = nil, -- Will be set after buffer is created
	}

	-- Open in new tab
	vim.cmd("tabnew")

	if not old_file_exists then
		-- New file - just show the content
		vim.cmd("edit " .. vim.fn.fnameescape(temp_file))
		vim.api.nvim_buf_set_name(0, new_file_path .. " (New file by Claude)")

		-- Store buffer for tracking
		local new_buf = vim.api.nvim_get_current_buf()
		active_diffs[tab_name].new_buffer = new_buf

		-- Set filetype
		if ext then
			local ft = vim.filetype.match({ filename = new_file_path })
			if ft then
				vim.bo.filetype = ft
			end
		end

		-- Add autocmds for buffer operations
		vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload", "BufWipeout" }, {
			group = autocmd_group,
			buffer = new_buf,
			callback = function()
				vim.notify(
					string.format("[Claude IDE] NEW FILE buffer close autocmd triggered for: %s", tab_name),
					vim.log.levels.WARN
				)
				if active_diffs[tab_name] and active_diffs[tab_name].status == "pending" then
					M.reject_diff(tab_name)
				end
			end,
		})

		-- Add autocmd for save (accept)
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			group = autocmd_group,
			buffer = new_buf,
			callback = function()
				if active_diffs[tab_name] and active_diffs[tab_name].status == "pending" then
					M.accept_new_file(tab_name)
				end
				return true -- Prevent actual write, we handle it
			end,
		})

		vim.notify(
			string.format("[Claude IDE] New file: %s. Save with :w to create", new_file_path),
			vim.log.levels.INFO
		)
	else
		-- Use native diff for file comparison (diffview is for git)
		vim.cmd("edit " .. vim.fn.fnameescape(old_file_path))

		vim.cmd("diffthis")

		vim.cmd("vnew " .. vim.fn.fnameescape(temp_file))
		vim.api.nvim_buf_set_name(0, new_file_path .. " (Claude's suggestion)")

		-- Store new buffer for tracking
		local new_buf = vim.api.nvim_get_current_buf()
		active_diffs[tab_name].new_buffer = new_buf

		-- Copy filetype for syntax highlighting
		local old_ft = vim.bo[vim.fn.bufnr(old_file_path)].filetype
		if old_ft and old_ft ~= "" then
			vim.bo.filetype = old_ft
		end

		vim.cmd("diffthis")
		vim.cmd("wincmd =")

		-- Add buffer-local keymaps for the new buffer (right side)
		vim.api.nvim_buf_set_keymap(
			0,
			"n",
			"<leader>au",
			string.format(":lua require('plugins.claude.diffview').accept_diff('%s')<CR>", tab_name),
			{ silent = true, desc = "Accept Claude's changes" }
		)
		vim.api.nvim_buf_set_keymap(
			0,
			"n",
			"<leader>ao",
			string.format(":lua require('plugins.claude.diffview').reject_diff('%s')<CR>", tab_name),
			{ silent = true, desc = "Reject Claude's changes" }
		)

		-- Also set keymaps for the original buffer (left side)
		local orig_buf = vim.fn.bufnr(old_file_path)
		if orig_buf ~= -1 then
			vim.api.nvim_buf_set_keymap(
				orig_buf,
				"n",
				"<leader>au",
				string.format(":lua require('plugins.claude.diffview').accept_diff('%s')<CR>", tab_name),
				{ silent = true, desc = "Accept Claude's changes" }
			)
			vim.api.nvim_buf_set_keymap(
				orig_buf,
				"n",
				"<leader>ao",
				string.format(":lua require('plugins.claude.diffview').reject_diff('%s')<CR>", tab_name),
				{ silent = true, desc = "Reject Claude's changes" }
			)
		end

		-- Add autocmds for buffer operations on the new buffer
		vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload", "BufWipeout" }, {
			group = autocmd_group,
			buffer = new_buf,
			callback = function()
				vim.notify(
					string.format("[Claude IDE] Buffer close autocmd triggered for: %s", tab_name),
					vim.log.levels.WARN
				)
				if active_diffs[tab_name] and active_diffs[tab_name].status == "pending" then
					M.reject_diff(tab_name)
				end
			end,
		})

		-- Add autocmd for save (accept) - using BufWriteCmd to intercept :w
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			group = autocmd_group,
			buffer = new_buf,
			callback = function()
				-- Save autocmd triggered
				if active_diffs[tab_name] and active_diffs[tab_name].status == "pending" then
					M.accept_diff(tab_name)
				end
				return true -- Prevent actual write, we handle it
			end,
		})

		vim.notify(
			string.format("[Claude IDE] Diff opened. Accept: <leader>ao | Reject: <leader>au", old_file_path),
			vim.log.levels.INFO
		)
	end

	-- Add autocmd to clean up temp file
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "TabClosed" }, {
		pattern = temp_file,
		once = true,
		callback = function()
			vim.fn.delete(temp_file)
			active_diffs[tab_name] = nil
		end,
	})

	return true
end

--- Open diff using native Neovim (fallback)
---@param old_file_path string
---@param new_file_path string
---@param new_file_contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.open_native_diff(old_file_path, new_file_path, new_file_contents, tab_name)
	-- Check if old file exists
	local old_file_exists = vim.fn.filereadable(old_file_path) == 1

	if not old_file_exists then
		-- New file creation
		return M.create_new_file(new_file_path, new_file_contents, tab_name)
	end

	-- Create temp file with new contents
	local ext = get_extension(old_file_path)
	local temp_file = create_temp_file(new_file_contents, ext)

	-- Store diff info
	active_diffs[tab_name] = {
		old_file = old_file_path,
		new_file = new_file_path,
		temp_file = temp_file,
		contents = new_file_contents,
	}

	-- Open in new tab
	vim.cmd("tabnew")

	-- Open original file on the left
	vim.cmd("edit " .. vim.fn.fnameescape(old_file_path))

	-- Set diff filler characters globally to use diagonal lines
	vim.opt.fillchars:append("diff:╱")

	vim.cmd("diffthis")

	-- Open new content on the right
	vim.cmd("vnew " .. vim.fn.fnameescape(temp_file))
	vim.api.nvim_buf_set_name(0, new_file_path .. " (Claude's suggestion)")

	-- Copy filetype for syntax highlighting
	local old_ft = vim.bo[vim.fn.bufnr(old_file_path)].filetype
	if old_ft and old_ft ~= "" then
		vim.bo.filetype = old_ft
	end

	vim.cmd("diffthis")
	vim.cmd("wincmd =")

	-- Add keymaps
	local opts = { buffer = true, silent = true }
	vim.keymap.set("n", "<leader>ao", function()
		M.accept_diff(tab_name)
	end, vim.tbl_extend("force", opts, { desc = "Accept Claude's changes" }))
	vim.keymap.set("n", "<leader>au", function()
		M.reject_diff(tab_name)
	end, vim.tbl_extend("force", opts, { desc = "Reject Claude's changes" }))

	vim.notify(
		string.format("[Claude IDE] Diff opened. Accept: <leader>ao | Reject: <leader>au", tab_name),
		vim.log.levels.INFO
	)

	-- Cleanup temp file on buffer close
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		buffer = vim.api.nvim_get_current_buf(),
		once = true,
		callback = function()
			vim.fn.delete(temp_file)
		end,
	})

	return true
end

--- Create new file
---@param file_path string
---@param contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.create_new_file(file_path, contents, tab_name)
	-- Store info
	active_diffs[tab_name] = {
		new_file = file_path,
		contents = contents,
		is_new = true,
	}

	-- Open in new tab
	vim.cmd("tabnew")
	vim.cmd("enew")

	-- Set content
	vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(contents, "\n"))
	vim.api.nvim_buf_set_name(0, file_path .. " (New file by Claude)")

	-- Set filetype
	local ext = get_extension(file_path)
	if ext then
		local ft = vim.filetype.match({ filename = file_path })
		if ft then
			vim.bo.filetype = ft
		end
	end

	-- Add keymaps
	local opts = { buffer = true, silent = true }
	vim.keymap.set("n", "<leader>ao", function()
		M.accept_new_file(tab_name)
	end, vim.tbl_extend("force", opts, { desc = "Accept new file" }))
	vim.keymap.set("n", "<leader>au", function()
		M.reject_diff(tab_name)
	end, vim.tbl_extend("force", opts, { desc = "Reject new file" }))

	vim.notify(
		string.format("[Claude IDE] New file: %s. Accept: <leader>ao | Reject: <leader>au", file_path),
		vim.log.levels.INFO
	)

	return true
end

--- Accept diff changes
---@param tab_name string
function M.accept_diff(tab_name)
	local diff = active_diffs[tab_name]
	if not diff then
		-- No active diff
		return
	end

	if diff.is_new then
		return M.accept_new_file(tab_name)
	end

	-- Mark as accepted
	diff.status = "accepted"

	-- Option 1: Apply changes directly in Neovim (more efficient)
	-- Uncomment this block if you want Neovim to apply the changes
	--[[
    if diff.temp_file and diff.old_file then
        vim.cmd("silent! !cp " .. vim.fn.fnameescape(diff.temp_file) .. " " .. vim.fn.fnameescape(diff.old_file))
        vim.cmd("checktime")  -- Reload the file
        -- Send a different response indicating file was already updated
            protocol.send_diff_response(tab_name, "accepted_and_applied", diff.contents)
    else
    --]]

	-- Option 2: Let Claude Code apply the changes (current default)
	-- Send deferred response to Claude Code (it will handle the file update)
	protocol.send_diff_response(tab_name, "accepted", diff.contents)

	--[[
    end
    --]]

	-- Reload the buffer after Claude Code applies the changes
	vim.defer_fn(function()
		-- Find the buffer for the original file and reload it
		if diff.old_file then
			local bufnr = vim.fn.bufnr(diff.old_file)
			if bufnr ~= -1 then
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd("checktime")
					vim.cmd("e")
				end)
				vim.notify("Buffer reloaded after accepting changes", vim.log.levels.INFO)
			end
		end
	end, 500) -- Small delay to let Claude Code apply the changes

	-- Clean up the diff view with a small delay to ensure response is sent first
	vim.defer_fn(function()
		-- Close diffview if open
		pcall(vim.cmd, "DiffviewClose")

		-- Find and close the tab containing our diff
		local closed = false

		-- Method 1: Find tab by checking for our diff buffer
		for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
			local wins = vim.api.nvim_tabpage_list_wins(tabpage)
			for _, win in ipairs(wins) do
				local buf = vim.api.nvim_win_get_buf(win)
				-- Check if this is our diff buffer
				if diff.new_buffer and buf == diff.new_buffer then
					-- Found our tab - close it
					vim.api.nvim_set_current_tabpage(tabpage)
					vim.cmd("tabclose")
					closed = true
					break
				elseif diff.temp_file then
					-- Also check by temp file path
					local buf_name = vim.api.nvim_buf_get_name(buf)
					if
						buf_name == diff.temp_file
						or buf_name:match("Claude's suggestion")
						or buf_name:match("claude_diff")
					then
						vim.api.nvim_set_current_tabpage(tabpage)
						vim.cmd("tabclose")
						closed = true
						break
					end
				end
			end
			if closed then
				break
			end
		end

		-- Method 2: If we couldn't find by buffer, try closing the current tab if it looks like a diff
		if not closed then
			local current_tab = vim.api.nvim_get_current_tabpage()
			local wins = vim.api.nvim_tabpage_list_wins(current_tab)
			for _, win in ipairs(wins) do
				local buf = vim.api.nvim_win_get_buf(win)
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if
					buf_name:match("Claude's suggestion")
					or buf_name:match("claude_diff")
					or buf_name:match("/tmp/")
				then
					vim.cmd("tabclose")
					closed = true
					break
				end
			end
		end

		-- Clean up buffers if they still exist
		if diff.new_buffer and vim.api.nvim_buf_is_valid(diff.new_buffer) then
			pcall(vim.api.nvim_buf_delete, diff.new_buffer, { force = true })
		end

		-- Clean up temp file
		if diff.temp_file then
			vim.fn.delete(diff.temp_file)
		end

		-- Diff closed
	end, 100) -- 100ms delay to ensure response is sent

	active_diffs[tab_name] = nil
	-- Changes accepted
end

--- Accept new file
---@param tab_name string
function M.accept_new_file(tab_name)
	local diff = active_diffs[tab_name]
	if not diff or not diff.is_new then
		-- No new file diff
		return
	end

	-- DON'T save the file - Claude Code will create it when it gets the response
	-- vim.cmd("write " .. vim.fn.fnameescape(diff.new_file))

	-- Send deferred response to Claude Code (it will create the file)
	protocol.send_diff_response(tab_name, "accepted", diff.contents)

	-- Clean up (Claude Code will create the file, we just close the preview)
	vim.schedule(function()
		vim.cmd("tabclose")
	end)

	active_diffs[tab_name] = nil
	-- Changes accepted for Claude Code
end

--- Reject diff
---@param tab_name string
function M.reject_diff(tab_name)
	local diff = active_diffs[tab_name]
	if not diff then
		-- No active diff
		return
	end

	-- Mark as rejected
	diff.status = "rejected"

	-- Send deferred response to Claude Code
	protocol.send_diff_response(tab_name, "rejected", nil)

	-- Clean up the diff view with a small delay to ensure response is sent first
	vim.defer_fn(function()
		-- Close diffview if open
		pcall(vim.cmd, "DiffviewClose")

		-- Find and close the tab containing our diff
		local closed = false

		-- Method 1: Find tab by checking for our diff buffer
		for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
			local wins = vim.api.nvim_tabpage_list_wins(tabpage)
			for _, win in ipairs(wins) do
				local buf = vim.api.nvim_win_get_buf(win)
				-- Check if this is our diff buffer
				if diff.new_buffer and buf == diff.new_buffer then
					-- Found our tab - close it
					vim.api.nvim_set_current_tabpage(tabpage)
					vim.cmd("tabclose")
					closed = true
					break
				elseif diff.temp_file then
					-- Also check by temp file path
					local buf_name = vim.api.nvim_buf_get_name(buf)
					if
						buf_name == diff.temp_file
						or buf_name:match("Claude's suggestion")
						or buf_name:match("claude_diff")
					then
						vim.api.nvim_set_current_tabpage(tabpage)
						vim.cmd("tabclose")
						closed = true
						break
					end
				end
			end
			if closed then
				break
			end
		end

		-- Method 2: If we couldn't find by buffer, try closing the current tab if it looks like a diff
		if not closed then
			local current_tab = vim.api.nvim_get_current_tabpage()
			local wins = vim.api.nvim_tabpage_list_wins(current_tab)
			for _, win in ipairs(wins) do
				local buf = vim.api.nvim_win_get_buf(win)
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if
					buf_name:match("Claude's suggestion")
					or buf_name:match("claude_diff")
					or buf_name:match("/tmp/")
				then
					vim.cmd("tabclose")
					closed = true
					break
				end
			end
		end

		-- Clean up buffers if they still exist
		if diff.new_buffer and vim.api.nvim_buf_is_valid(diff.new_buffer) then
			pcall(vim.api.nvim_buf_delete, diff.new_buffer, { force = true })
		end

		-- Clean up temp file
		if diff.temp_file then
			vim.fn.delete(diff.temp_file)
		end

		-- Diff closed
	end, 100) -- 100ms delay to ensure response is sent

	active_diffs[tab_name] = nil
	-- Changes rejected
end

--- Get active diffs (for closeAllDiffTabs)
---@return table
function M.get_active_diffs()
	return active_diffs
end

--- Close diff by tab name (for closeTab tool)
---@param tab_name string
---@return boolean success
function M.close_diff_by_tab_name(tab_name)
	-- Closing diff by tab name
	logger.info(string.format("close_diff_by_tab_name called with: %s", tab_name))

	-- Debug: Show all active diffs
	vim.notify(
		string.format("[Claude IDE] Active diffs: %s", vim.inspect(vim.tbl_keys(active_diffs))),
		vim.log.levels.DEBUG
	)

	-- Try to find and close the diff by exact match or pattern
	for stored_name, diff in pairs(active_diffs) do
		vim.notify(
			string.format("[Claude IDE] Checking stored diff: %s against %s", stored_name, tab_name),
			vim.log.levels.DEBUG
		)
		logger.debug(string.format("Checking stored diff: %s", stored_name))
		-- Check if it matches exactly or if the stored name contains the file name from tab_name
		if
			stored_name == tab_name
			or (tab_name:match("✻") and stored_name:match("✻"))
			or (
				tab_name
				and stored_name
				and vim.fn.fnamemodify(tab_name, ":t") == vim.fn.fnamemodify(stored_name, ":t")
			)
		then
			-- Found matching diff
			logger.info(string.format("Found matching diff, rejecting: %s", stored_name))
			-- Avoid double notification by marking as already handled
			if diff.status == "pending" then
				diff.status = "rejected"
				-- Close the diff without sending notification (Claude already knows)
				if diff.temp_file then
					vim.fn.delete(diff.temp_file)
				end
				-- Close tab
				for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
					for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
						local buf = vim.api.nvim_win_get_buf(win)
						if buf == diff.new_buffer then
							vim.api.nvim_set_current_tabpage(tabpage)
							vim.cmd("tabclose")
							break
						end
					end
				end
				active_diffs[stored_name] = nil
				-- Diff closed by Claude Code
			else
				vim.notify(
					string.format("[Claude IDE] Diff status not pending: %s", diff.status or "nil"),
					vim.log.levels.WARN
				)
			end
			return true
		end
	end

	-- No matching diff found
	logger.warn(string.format("No matching diff found for tab_name: %s", tab_name))
	return false
end

--- Main entry point - tries diffview first, falls back to native
---@param old_file_path string
---@param new_file_path string
---@param new_file_contents string
---@param tab_name string
---@return boolean success
---@return string|nil error
function M.open_diff(old_file_path, new_file_path, new_file_contents, tab_name)
	vim.notify(
		string.format(
			"[Claude IDE] open_diff called - old: %s, new: %s, tab: %s",
			old_file_path,
			new_file_path,
			tab_name
		),
		vim.log.levels.INFO
	)

	-- Try diffview first
	if has_diffview() then
		local ok, success, err = pcall(M.open_diffview, old_file_path, new_file_path, new_file_contents, tab_name)
		if not ok then
			vim.notify(
				string.format("[Claude IDE] Error in open_diffview: %s", tostring(success)),
				vim.log.levels.ERROR
			)
			return false, tostring(success)
		end
		return success, err
	end

	-- Fallback to native diff
	local ok, success, err = pcall(M.open_native_diff, old_file_path, new_file_path, new_file_contents, tab_name)
	if not ok then
		-- Error in open_native_diff
		return false, tostring(success)
	end
	return success, err
end

--- Blocking version that waits for user decision
---@param old_file_path string
---@param new_file_path string
---@param new_file_contents string
---@param tab_name string
---@return boolean success
---@return table result MCP-compliant response
function M.open_diff_blocking(old_file_path, new_file_path, new_file_contents, tab_name)
	local co = coroutine.running()
	if not co then
		-- Not in coroutine context, fall back to non-blocking
		local success, err = M.open_diff(old_file_path, new_file_path, new_file_contents, tab_name)
		if success then
			return true, {
				content = {
					{ type = "text", text = "DIFF_OPENED" },
				},
			}
		else
			return false, err
		end
	end

	-- Store callback for when decision is made
	local callback = function(decision, content)
		local result
		if decision == "accepted" then
			result = {
				content = {
					{ type = "text", text = "FILE_SAVED" },
					{ type = "text", text = content or "" },
				},
			}
		else
			result = {
				content = {
					{ type = "text", text = "DIFF_REJECTED" },
					{ type = "text", text = tab_name },
				},
			}
		end
		-- Resume coroutine with result
		coroutine.resume(co, true, result)
	end

	-- Open the diff
	local success, err = M.open_diff(old_file_path, new_file_path, new_file_contents, tab_name)
	if not success then
		return false, err
	end

	-- Store the callback in the diff data
	if active_diffs[tab_name] then
		active_diffs[tab_name].resolution_callback = callback
	end

	-- Yield coroutine and wait for callback
	return coroutine.yield()
end

return M
