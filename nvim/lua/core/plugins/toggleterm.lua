local M = {}

local options = {
	size = function(term)
		if term.direction == "horizontal" then
			return 20
		elseif term.direction == "vertical" then
			return vim.o.columns * 0.4
		end
	end,
	hide_numbers = true,
	shade_filetypes = {},
	shade_terminals = true,
	shading_factor = 1,    -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
	start_in_insert = true,
	insert_mappings = true, -- whether or not the open mapping applies in insert mode
	persist_size = false,
	close_on_exit = true,
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
	local opts = { buffer = 0 }
	vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
	vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
	vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
	vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
	vim.keymap.set('t', '<C-l>', [[<Cmd>TermExec cmd="clear"<CR>]], opts)
	vim.keymap.set('t', '<C-w>', [[<Cmd>TermExec cmd="exit"<CR>]], opts)
end

M.configure = function()
	local Terminal = require('toggleterm.terminal').Terminal
	function LAZYGIT_TOGGLE()
		local width = math.floor(vim.o.columns * 0.98)
		local height = math.floor(vim.o.lines * 0.94)
		local lazygit = Terminal:new({
			cmd = "lazygit",
			hidden = true,
			direction = "float",
			count = 99,
			shade_terminals = false,
			float_opts = {
				width = width,
				height = height,
			},
			on_open = function(term)
				vim.cmd("startinsert!")
			end,
			on_close = function()
				vim.cmd("startinsert!")
			end,
		})

		lazygit:toggle()
	end

	require("toggleterm").setup(options)
	vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')
	vim.api.nvim_set_keymap("n", "<leader>G", "<cmd>lua LAZYGIT_TOGGLE()<CR>",
		{ desc = "Lazygit", noremap = true, silent = true })
end

return M
