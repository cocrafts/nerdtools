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

M.find_project_files = function(opts)
	local builtin = require("telescope.builtin")

	opts = opts or {}
	local ok = pcall(builtin.git_files, opts)

	if not ok then
		builtin.find_files(opts)
	end
end

M.open_lsp_definitions = function()
	local function exclude_react_index_d_ts(result)
		local uri = result.uri or result.targetUri
		if not uri then
			return false
		end
		local path = vim.uri_to_fname(uri)
		return not string.match(path, "react[/\\]index.d.ts$")
	end

	local results = vim.lsp.buf_request_sync(0, "textDocument/definition", vim.lsp.util.make_position_params(), 1000)

	for _client_id, response in pairs(results or {}) do
		if response.result and vim.tbl_islist(response.result) then
			-- Filter out unwanted results
			local filtered_results = vim.tbl_filter(exclude_react_index_d_ts, response.result)

			if #filtered_results == 1 then
				-- If there's exactly one result after filtering, jump to it directly
				vim.lsp.util.jump_to_location(filtered_results[1])
				return
			elseif #filtered_results > 1 then
				-- If there are multiple results after filtering, use Telescope to display them
				require("telescope.builtin").lsp_definitions(M.layouts.full_cursor())
				return
			end
		end
	end

	-- Fallback in case no results are found or some other unexpected behavior
	print("No definitions found")
end

return M
