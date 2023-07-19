local M = {}
local icons = require("utils.icons")

M.configure = function()
	require("noice").setup({
		lsp = {
			-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = true,
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
					{ icons.ui.FolderEmpty .. " ", hl_group = "NoiceLspProgressSpinner" },
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
			lsp_doc_border = false, -- add a border to hover docs and signature help
		},
	})
end

return M
