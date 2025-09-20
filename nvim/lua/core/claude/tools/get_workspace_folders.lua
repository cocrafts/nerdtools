--- Tool for getting workspace folders
--- @module 'core.claude.tools.get_workspace_folders'

local M = {}

M.name = "get_workspace_folders"

M.schema = {
	description = "Get the workspace folders (project roots) currently open",
	inputSchema = {
		type = "object",
		properties = {},
		additionalProperties = false,
	},
}

--- Find project root from current directory
--- @param path string Starting path
--- @return string|nil Project root path
local function find_project_root(path)
	local root_markers = {
		".git",
		".svn",
		".hg",
		"package.json",
		"Cargo.toml",
		"go.mod",
		"pom.xml",
		"build.gradle",
		"Makefile",
		"CMakeLists.txt",
		".project",
		".vscode",
		".idea",
	}

	local current = path
	local home = vim.fn.expand("~")

	while current and current ~= "/" and current ~= home do
		for _, marker in ipairs(root_markers) do
			local marker_path = current .. "/" .. marker
			if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
				return current
			end
		end
		current = vim.fn.fnamemodify(current, ":h")
	end

	return nil
end

--- Handle get_workspace_folders tool invocation
--- @param params table Input parameters (unused)
--- @return table Response with workspace folders
function M.handler(params)
	local workspace_folders = {}
	local seen_folders = {}

	-- Get current working directory
	local cwd = vim.fn.getcwd()
	table.insert(workspace_folders, {
		name = vim.fn.fnamemodify(cwd, ":t"),
		uri = "file://" .. cwd,
		path = cwd,
		is_cwd = true,
	})
	seen_folders[cwd] = true

	-- Check for LSP workspace folders
	if vim.lsp then
		for _, client in pairs(vim.lsp.get_active_clients()) do
			if client.config and client.config.workspace_folders then
				for _, folder in ipairs(client.config.workspace_folders) do
					local path = folder.uri:gsub("^file://", "")
					if not seen_folders[path] then
						table.insert(workspace_folders, {
							name = folder.name or vim.fn.fnamemodify(path, ":t"),
							uri = folder.uri,
							path = path,
							is_lsp = true,
						})
						seen_folders[path] = true
					end
				end
			end
		end
	end

	-- Check project roots from open buffers
	local buffers = vim.api.nvim_list_bufs()
	for _, bufnr in ipairs(buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			if filepath ~= "" then
				local dir = vim.fn.fnamemodify(filepath, ":h")
				local root = find_project_root(dir)
				if root and not seen_folders[root] then
					table.insert(workspace_folders, {
						name = vim.fn.fnamemodify(root, ":t"),
						uri = "file://" .. root,
						path = root,
						is_detected = true,
					})
					seen_folders[root] = true
				end
			end
		end
	end

	-- Format response
	local response_text = "Workspace folders: " .. #workspace_folders .. "\n\n"

	if #workspace_folders > 0 then
		for _, folder in ipairs(workspace_folders) do
			response_text = response_text .. folder.name .. "\n"
			response_text = response_text .. "  Path: " .. folder.path .. "\n"

			local details = {}
			if folder.is_cwd then
				table.insert(details, "current working directory")
			end
			if folder.is_lsp then
				table.insert(details, "LSP workspace")
			end
			if folder.is_detected then
				table.insert(details, "detected project root")
			end

			if #details > 0 then
				response_text = response_text .. "  Type: " .. table.concat(details, ", ") .. "\n"
			end

			response_text = response_text .. "\n"
		end
	else
		response_text = response_text .. "No workspace folders found."
	end

	return {
		content = {
			{
				type = "text",
				text = response_text,
			},
		},
		_raw_folders = workspace_folders,
	}
end

return M