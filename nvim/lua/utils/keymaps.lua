local key = require("utils.key")

key.mode_keys("i", {})

key.mode_keys("n", {
	-- Window movement
	["<C-h>"] = "<C-w>h",
	["<C-j>"] = "<C-w>j",
	["<C-k>"] = "<C-w>k",
	["<C-l>"] = "<C-w>l",

	["<C-x>"] = ":split<CR>:b#<CR>",
	["<C-s>"] = ":vsplit<CR>:b#<CR>",
	["<C-g>"] = ":tabnew<CR>",
	["<leader>'"] = ":tabclose<CR>",

	["<TAB>"] = ":bnext<CR>",
	["<S-TAB>"] = ":bprev<CR>",

	["H"] = "Hzz",
	["L"] = "Lzz",
	["n"] = "nzz",
	["N"] = "Nzz",

	-- Git navigation
	["<C-f>"] = "<cmd>lua require('gitsigns').next_hunk()<CR>:lua vim.api.nvim_feedkeys('zz', 'n', true)<CR>",
	["<C-a>"] = "<cmd>lua require('gitsigns').prev_hunk()<CR>:lua vim.api.nvim_feedkeys('zz', 'n', true)<CR>",

	["*"] = "<cmd>lua require('utils.helper').toggle_highlight_search()<CR>",
})

key.mode_keys("v", {
	["J"] = ":m '>+1<CR>gv=gv",
	["K"] = ":m '<-2<CR>gv=gv",
	["<"] = "<gv",
	[">"] = ">gv",
})

if vim.g.neovide then
	vim.g.neovide_input_use_logo = 1                                                  -- enable use of the logo (cmd) key
	vim.keymap.set("n", "<D-s>", ":up<CR>")                                           -- Save
	vim.keymap.set("v", "<D-c>", '"+y')                                               -- Copy
	vim.keymap.set("n", "<D-v>", '"+P')                                               -- Paste normal mode
	vim.keymap.set("v", "<D-v>", '"+P')                                               -- Paste visual mode
	vim.keymap.set("c", "<D-v>", "<C-R>+")                                            -- Paste command mode
	vim.keymap.set("i", "<D-v>", '<ESC>l"+Pli')                                       -- Paste insert mode
	vim.api.nvim_set_keymap("!", "<D-v>", "<C-R>+", { noremap = true, silent = true }) -- Allow insert mode paste

	-- Runtime font scale
	vim.g.neovide_scale_factor = 1.0
	local change_scale_factor = function(delta)
		vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
	end
	vim.keymap.set("n", "<C-=>", function()
		change_scale_factor(1.25)
	end)
	vim.keymap.set("n", "<C-->", function()
		change_scale_factor(1 / 1.25)
	end)

	vim.keymap.set("n", "<D-d>", '"+yyp') -- Duplicate line
	vim.keymap.set("i", "<D-d>", '<ESC>"+yyp')
	vim.keymap.set("v", "<D-d>", '"+yP')

	vim.keymap.set("n", "<D-Left>", ":bnext<CR>") -- Jump to next buffer
	vim.keymap.set("i", "<D-Left>", "<ESC>:bnext<CR>")

	vim.keymap.set("n", "<D-Right>", ":bprev<CR>") -- Jump to prev buffer
	vim.keymap.set("i", "<D-Right>", "<ESC>:bprev<CR>")
end

-- Disable middlemouse paste
vim.keymap.set("", "<MiddleMouse>", "<Nop>")
vim.keymap.set("", "<2-MiddleMouse>", "<Nop>")
vim.keymap.set("", "<3-MiddleMouse>", "<Nop>")
vim.keymap.set("", "<4-MiddleMouse>", "<Nop>")
