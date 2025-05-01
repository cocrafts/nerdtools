local M = {}

M.mergeTables = function(t1, t2)
	if t1 == nil then
		return t2
	end

	for k, v in pairs(t2) do
		t1[k] = v
	end

	return t1
end

M.valueExists = function(item, items)
	for _, value in ipairs(items) do
		if item == value then
			return true
		end
	end

	return false
end

M.layouts = {
	full_cursor = function(height)
		return require("telescope.themes").get_cursor({
			layout_config = {
				width = function(_, max_columns, _)
					return max_columns - 6
				end,
				height = height or 12,
			},
		})
	end,
}

M.close_other_buffers = function()
	local bufs = vim.api.nvim_list_bufs()
	local current_buf = vim.api.nvim_get_current_buf()
	for _, buf in ipairs(bufs) do
		local buf_name = vim.fn.bufname(buf)
		if (buf_name and string.sub(buf_name, 1, 8)) ~= "neo-tree" and buf ~= current_buf then
			vim.api.nvim_buf_delete(buf, {})
		end
	end
end

M.find_project_files = function(opts)
	local builtin = require("telescope.builtin")

	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

M.open_lsp_definitions = function()
	local standard_result = vim.lsp.buf.definition()

	if not standard_result then
		local function exclude_react_index_d_ts(result)
			local uri = result.uri or result.targetUri
			if not uri then
				return false
			end
			local path = vim.uri_to_fname(uri)
			return not string.match(path, "react[/\\]index.d.ts$")
		end

		local results =
				vim.lsp.buf_request_sync(0, "textDocument/definition", vim.lsp.util.make_position_params(), 1000)

		for _client_id, response in pairs(results or {}) do
			if response.result and vim.islist(response.result) then
				local filtered_results = vim.tbl_filter(exclude_react_index_d_ts, response.result)

				if #filtered_results == 1 then
					vim.lsp.util.show_document(filtered_results[1], "utf-8", { focus = true })
					return
				elseif #filtered_results > 1 then
					require("telescope.builtin").lsp_definitions(M.layouts.full_cursor())
					return
				end
			end
		end

		print("No definitions found")
	end
end

local last_search_pattern = ""
M.toggle_highlight_search = function()
	local search_pattern = vim.fn.getreg("/") or ""

	if search_pattern ~= last_search_pattern then
		last_search_pattern = search_pattern
		vim.cmd([[normal! *]])
	else
		vim.cmd("nohlsearch")
		last_search_pattern = ""
	end
end

return M
