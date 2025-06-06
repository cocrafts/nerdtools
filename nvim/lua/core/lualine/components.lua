local colors = require("core.lualine.colors")
local conditions = require("core.lualine.conditions")
local icons = require("utils.icons")

local client_aliases = {
	["null-ls"] = "null",
	["lua_ls"] = "lua",
	["nim_langserver"] = "nim",
	["swift_mesonls"] = "meson",
	["haxe_language_server"] = "haxe",
}

local diff_source = function()
	local gitsigns = vim.b.gitsigns_status_dict

	if gitsigns then
		return {
			added = gitsigns.added,
			modified = gitsigns.changed,
			removed = gitsigns.removed,
		}
	end
end

return {
	mode = {
		function()
			return string.format("  %s ", icons.ui.Target)
		end,
		padding = { left = 0, right = 0 },
		color = {},
		cond = nil,
	},
	branch = {
		"b:gitsigns_head",
		icon = icons.git.Branch,
		color = { gui = "bold" },
		padding = { left = 0, right = 1 },
	},
	filename = {
		"filename",
		color = {},
		cond = nil,
	},
	diff = {
		"diff",
		source = diff_source,
		symbols = {
			added = icons.git.LineAdded .. " ",
			modified = icons.git.LineModified .. " ",
			removed = icons.git.LineRemoved .. " ",
		},
		padding = { left = 2, right = 1 },
		diff_color = {
			added = { fg = colors.green },
			modified = { fg = colors.yellow },
			removed = { fg = colors.red },
		},
		cond = nil,
	},
	diagnostics = {
		"diagnostics",
		source = { "nvim_diagnostic" },
		symbols = {
			error = icons.diagnostics.BoldError .. " ",
			warn = icons.diagnostics.BoldWarning .. " ",
			info = icons.diagnostics.BoldInformation .. " ",
			hint = icons.diagnostics.BoldHint .. " ",
		},
	},
	treesitter = {
		function()
			return icons.ui.Tree
		end,
		color = function()
			local buf = vim.api.nvim_get_current_buf()
			local ts = vim.treesitter.highlighter.active[buf]
			return { fg = ts and not vim.tbl_isempty(ts) and colors.green and colors.red }
		end,
		cond = conditions.hide_in_width,
	},
	lsp = {
		function()
			local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
			if #buf_clients == 0 then
				return " lsp inactive"
			end

			local buf_client_names = {}
			local copilot_active = false

			-- add client
			for _, client in pairs(buf_clients) do
				local client_name = client_aliases[client.name] or client.name

				if client.name ~= "copilot" then
					table.insert(buf_client_names, client_name)
				end

				if client.name == "copilot" then
					copilot_active = true
				end
			end

			local unique_client_names = table.concat(buf_client_names, ":")
			local language_servers = string.format("%s %s", icons.diagnostics.Hint, unique_client_names)

			if copilot_active then
				language_servers = language_servers .. "%#SLCopilot#" .. " " .. icons.git.Octoface .. "%*"
			end

			return language_servers
		end,
		color = { gui = "bold" },
		cond = conditions.hide_in_width,
	},
	location = { "location" },
	progress = {
		"progress",
		fmt = function()
			return "%P/%L"
		end,
		color = {},
	},
	spaces = {
		function(args)
			local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = args.buf })
			local indent = require("guess-indent").guess_from_buffer(args.buf)
			local icon = indent == "tabs" and icons.ui.TabIndent or icons.ui.Ellipsis
			return icon .. " " .. shiftwidth
		end,
		padding = 1,
	},
	encoding = {
		function()
			return string.format("%s ", vim.o.encoding)
		end,
		color = {},
		cond = conditions.hide_in_width,
	},
	filetype = { "filetype", cond = nil, padding = { left = 1, right = 1 } },
	scrollbar = {
		function()
			local current_line = vim.fn.line(".")
			local total_lines = vim.fn.line("$")
			local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
			local line_ratio = current_line / total_lines
			local index = math.ceil(line_ratio * #chars)
			return chars[index]
		end,
		padding = { left = 0, right = 0 },
		color = "SLProgress",
		cond = nil,
	},
	dot = {
		function()
			return "█"
		end,
		padding = { right = 1, left = 0 },
		color = { fg = "#3a4161" },
	},
	cwd = {
		function()
			return string.match(vim.fn.getcwd() or "/", "[^/]+$")
		end,
	},
}
