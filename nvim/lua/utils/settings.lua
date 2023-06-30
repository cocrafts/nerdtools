local globals = {
	mapleader = " ",
	localmapleader = " ",
	neovide_cursor_vfx_mode = "pixiedust",
	neovide_remember_window_size = true,
	gitblame_highlight_group = "GitBlame",
	gitblame_date_format = "%r",
	gitblame_message_template = " <author>, <date> • <summary> ",
	gitblame_message_when_not_committed = "",
}

local opts = {
	spell = true,
	spelllang = "en_us",
	guifont = "OperatorMonoLig Nerd Font Mono:h14",
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
	-- utilities
	title = true,     -- show buffer name in window title
	undofile = true,  -- enable persistent undo
	cursorline = true, -- highlight current line
	hlsearch = true,  -- highlight all matches on previous search pattern
	incsearch = true,
	ignorecase = true, -- ignore case when search
	smartcase = true,
	mouse = "a",
	-- line numbers
	number = true,        -- show line numbers
	relativenumber = true, -- show relative numbers
	numberwidth = 3,
	termguicolors = true,
	-- invisible characters
	list = true,
	listchars = {
		tab = " ",
		eol = "¬",
		space = "·",
	},
}

local defer_opts = {
	-- use tab
	autoindent = true,
	tabstop = 2,   -- insert 2 spaces for a tab
	shiftwidth = 2, -- number of spaces inserted for each indentation
}

for k, v in pairs(globals) do
	vim.g[k] = v
end

for k, v in pairs(opts) do
	vim.opt[k] = v
end

vim.defer_fn(function()
	for k, v in pairs(defer_opts) do
		vim.opt[k] = v
	end
end, 0)

-- undercurl for Wezterm
vim.api.nvim_set_option("t_Cs", "\27[4:3m")
vim.api.nvim_set_option("t_Ce", "\27[4:0m")

-- Neovide copy/paste
if vim.g.neovide then
  vim.g.neovide_input_use_logo = 1 -- enable use of the logo (cmd) key
  vim.keymap.set('n', '<D-s>', ':w<CR>') -- Save
  vim.keymap.set('v', '<D-c>', '"+y') -- Copy
  vim.keymap.set('n', '<D-v>', '"+P') -- Paste normal mode
  vim.keymap.set('v', '<D-v>', '"+P') -- Paste visual mode
  vim.keymap.set('c', '<D-v>', '<C-R>+') -- Paste command mode
  vim.keymap.set('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

-- Allow clipboard copy paste in neovim
vim.g.neovide_input_use_logo = 1
vim.api.nvim_set_keymap('', '<D-v>', '+p<CR>', { noremap = true, silent = true})
vim.api.nvim_set_keymap('!', '<D-v>', '<C-R>+', { noremap = true, silent = true})
vim.api.nvim_set_keymap('t', '<D-v>', '<C-R>+', { noremap = true, silent = true})
vim.api.nvim_set_keymap('v', '<D-v>', '<C-R>+', { noremap = true, silent = true})

