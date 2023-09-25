local M = {}
local icons = require("utils.icons")

M.configure = function()
	require("noice").setup({
		cmdline = {
			format = {
				cmdline = {
					title = "",
					pattern = "^:",
					icon = icons.ui.DoubleChevronRight,
					lang = "vim",
				},
				search_down = {
					kind = "search",
					pattern = "^/",
					icon = "  " .. icons.ui.Search,
					lang = "regex",
				},
				search_up = {
					kind = "search",
					pattern = "^%?",
					icon = "  " .. icons.ui.Search,
					lang = "regex",
				},
				filter = {
					pattern = "^:%s*!",
					icon = "  $",
					lang = "bash",
				},
				lua = {
					pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" },
					icon = "  ",
					lang = "lua",
				},
			},
		},
		views = {
			cmdline_popup = {
				border = { style = "none" },
			},
		},
		lsp = {
			-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				-- ["vim.lsp.util.stylize_markdown"] = true,
				-- ["cmp.entry.get_documentation"] = true,
			},
			progress = {
				enabled = true,
				format = {
					{ "{data.progress.percentage} ", hl_group = "NoiceLspProgressTitle" },
					{ "{spinner} ", hl_group = "NoiceLspProgressSpinner" },
					{ "{data.progress.title} ", hl_group = "NoiceLspProgressTitle" },
					{ "{data.progress.client} ", hl_group = "NoiceLspProgressClient" },
				},
				format_done = {
					{ icons.kind.Event .. " ", hl_group = "NoiceLspProgressSpinner" },
					{ "{data.progress.title} ", hl_group = "NoiceLspProgressTitle" },
					{ "{data.progress.client} ", hl_group = "NoiceLspProgressClient" },
				},
			},
		},
		-- you can enable a preset for easier configuration
		presets = {
			bottom_search = true, -- use a classic bottom cmdline for search
			command_palette = true, -- position the cmdline and popupmenu together
			long_message_to_split = true, -- long messages will be sent to a split
			inc_rename = false, -- enables an input dialog for inc-rename.nvim
			lsp_doc_border = true, -- add a border to hover docs and signature help
		},
	})
end

return M
