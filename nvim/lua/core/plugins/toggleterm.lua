local M = {}

local options = {
	size = function(term)
		if term.direction == "horizontal" then
			return 20
		elseif term.direction == "vertical" then
			return vim.o.columns * 0.4
		end
	end,
	-- direction = "float",
	float_opts = {
		border = "curved",
		winblend = 0,
		highlights = {
			border = "Normal",
			background = "Normal",
		},
	},
	open_mapping = [[<c-\>]],
	winbar = {
		enabled = false,
		name_formater = function(term)
			return term.name
		end,
	}
}

function _G.set_terminal_keymaps()
  local opts = {buffer = 0}
  vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
  vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
  vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
end

M.configure = function()
	require("toggleterm").setup(options)

	local Terminal  = require('toggleterm.terminal').Terminal
	local lazygit = Terminal:new({
		cmd = "lazygit",
		hidden = true,
		direction = "float",
		float_opts = {
			border = "none",
			width = 100000,
			height = 100000,
		},
		count = 99,
	})

	function LAZYGIT_TOGGLE()
		lazygit:toggle()
	end

	vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
	vim.api.nvim_set_keymap("n", "<leader>kg", "<cmd>lua LAZYGIT_TOGGLE()<CR>", { noremap = true, silent = true })
end

return M
