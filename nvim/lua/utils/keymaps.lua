local key = require("utils.key")

key.mode_keys("i", {})

key.mode_keys("n", {
	-- Window movement
	["<C-h>"] = "<C-w>h",
	["<C-j>"] = "<C-w>j",
	["<C-k>"] = "<C-w>k",
	["<C-l>"] = "<C-w>l",

	["<C-x>"] = ":split<CR>",
	["<C-v>"] = ":vsplit<CR>",

	["<TAB>"] = "<cmd>lua require('harpoon.ui').nav_next()<CR>",
	["<S-TAB>"] = "<cmd>lua require('harpoon.ui').nav_prev()<CR>",

	["<C-1>"] = "<cmd>lua require('harpoon.ui').nav_file(1)<CR>",
	["<C-2>"] = "<cmd>lua require('harpoon.ui').nav_file(2)<CR>",
	["<C-3>"] = "<cmd>lua require('harpoon.ui').nav_file(3)<CR>",
	["<C-4>"] = "<cmd>lua require('harpoon.ui').nav_file(4)<CR>",
	["<C-5>"] = "<cmd>lua require('harpoon.ui').nav_file(5)<CR>",
	["<C-6>"] = "<cmd>lua require('harpoon.ui').nav_file(6)<CR>",
	["<C-7>"] = "<cmd>lua require('harpoon.ui').nav_file(7)<CR>",
	["<C-8>"] = "<cmd>lua require('harpoon.term').gotoTerminal(2)<CR>",
	["<C-9>"] = "<cmd>lua require('harpoon.term').gotoTerminal(1)<CR>",

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
	vim.g.neovide_input_use_logo = 1 -- enable use of the logo (cmd) key
	vim.keymap.set("n", "<D-s>", ":up<CR>") -- Save
	vim.keymap.set("v", "<D-c>", '"+y') -- Copy
	vim.keymap.set("n", "<D-v>", '"+P') -- Paste normal mode
	vim.keymap.set("v", "<D-v>", '"+P') -- Paste visual mode
	vim.keymap.set("c", "<D-v>", "<C-R>+") -- Paste command mode
	vim.keymap.set("i", "<D-v>", '<ESC>l"+Pli') -- Paste insert mode
end

-- Allow clipboard copy paste in neovide
vim.g.neovide_input_use_logo = 1
vim.api.nvim_set_keymap("", "<D-v>", "+p<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<D-v>", "<C-R>+", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<D-v>", "<C-R>+", { noremap = true, silent = true })
