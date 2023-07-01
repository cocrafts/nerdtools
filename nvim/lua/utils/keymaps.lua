local key = require("utils.key")

key.mode_keys("i", {

})

key.mode_keys("n", {
	-- Window movement
	["<C-h>"] = "<C-w>h",
	["<C-j>"] = "<C-w>j",
	["<C-k>"] = "<C-w>k",
	["<C-l>"] = "<C-w>l",

	["<C-x>"] = ":split<CR>",
	["<C-v>"] = ":vsplit<CR>",

	["<TAB>"] = ":BufferLineCycleNext<CR>",
	["<S-Tab>"] = ":BufferLineCyclePrev<CR>",

	["H"] = "Hzz",
	["L"] = "Lzz",

	-- Git navigation
	["<C-f>"] = "<cmd>lua require('gitsigns').next_hunk()<CR>",
	["<C-s>"] = "<cmd>lua require('gitsigns').prev_hunk()<CR>",
})

key.mode_keys("v", {
	["<"] = "<gv",
	[">"] = ">gv",
})

-- Neovide copy/paste
if vim.g.neovide then
	vim.g.neovide_input_use_logo = 1           -- enable use of the logo (cmd) key
	vim.keymap.set('n', '<D-s>', ':w<CR>')     -- Save
	vim.keymap.set('v', '<D-c>', '"+y')        -- Copy
	vim.keymap.set('n', '<D-v>', '"+P')        -- Paste normal mode
	vim.keymap.set('v', '<D-v>', '"+P')        -- Paste visual mode
	vim.keymap.set('c', '<D-v>', '<C-R>+')     -- Paste command mode
	vim.keymap.set('i', '<D-v>', '<ESC>l"+Pli') -- Paste insert mode
end

-- Allow clipboard copy paste in neovide
vim.g.neovide_input_use_logo = 1
vim.api.nvim_set_keymap('', '<D-v>', '+p<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('!', '<D-v>', '<C-R>+', { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<D-v>', '<C-R>+', { noremap = true, silent = true })
vim.api.nvim_set_keymap('v', '<D-v>', '<C-R>+', { noremap = true, silent = true })
