local M = {}

M.configure = function()
	local cmp = require("cmp")
	local action = require("lsp-zero").cmp_action()

	---@diagnostic disable-next-line: redundant-parameter
	cmp.setup({
		sources = {
			{ name = "path" },
			{ name = "nvim_lsp" },
			{ name = "cmdline" },
			{ name = "buffer",  keyword_length = 3 },
			{ name = "luasnip", keyword_length = 2 },
		},
		mapping = {
			-- `Enter` key to confirm completion
			['<CR>'] = cmp.mapping.confirm({ select = false }),
			-- Ctrl+Space to trigger completion menu
			['<C-Space>'] = cmp.mapping.complete(),
			-- Navigate between snippet placeholder
			['<C-f>'] = action.luasnip_jump_forward(),
			['<C-b>'] = action.luasnip_jump_backward(),
		},
	})
end

return M
