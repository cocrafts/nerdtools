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
