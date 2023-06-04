local M = {}

M.configure = function(hints)
	local rustools = require("rust-tools")

	rustools.setup({
		tools = {
			inlay_hints = {
				auto = false,
			},
		},
		hover_actions = {
			border = {
				{ "╭", "FloatBorder" },
				{ "─", "FloatBorder" },
				{ "╮", "FloatBorder" },
				{ "│", "FloatBorder" },
				{ "╯", "FloatBorder" },
				{ "─", "FloatBorder" },
				{ "╰", "FloatBorder" },
				{ "│", "FloatBorder" },
			},
			max_width = nil, -- Maximal width of the hover window. Nil means no max.
			max_height = nil, -- Maximal height of the hover window. Nil means no max.
			auto_focus = false, -- whether the hover action window gets automatically focused
		},
		server = {
			on_attach = function(_, bufnr)
				vim.cmd("set autoindent tabstop=2 shiftwidth=2") -- force 2 space tabs

				vim.keymap.set("n", "<C-space>", rustools.hover_actions.hover_actions, { buffer = bufnr })
				vim.keymap.set("n", "<leader>a", rustools.code_action_group.code_action_group, { buffer = bufnr })
			end,
		},
	})
end

return M
