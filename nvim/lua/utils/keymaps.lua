local key = require("utils.key")

key.mode_keys("i", {

})

key.mode_keys("n", {
	-- Hop, fast navigation
	["ss"] = ":HopWordBC<CR>",
	["sf"] = ":HopWordAC<CR>",
	["sc"] = ":HopChar2<CR>",
	["sw"] = ":HopWord<CR>",
	["sp"] = ":HopPattern<CR>",
	["sl"] = ":HopLine<CR>",

	-- Search and replace
	["sR"] = ":lua require('spectre').open()<CR>",
	["sF"] = ":lua require('spectre').open_file_search()<CR>",
	["sW"] = ":lua require('spectre').open_visual({ select_word = true })<CR>",

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
	["f"] = "<cmd>lua require('gitsigns').next_hunk()<CR>",
	["F"] = "<cmd>lua require('gitsigns').prev_hunk()<CR>",
})

key.mode_keys("v", {
	["<"] = "<gv",
	[">"] = ">gv",
})
