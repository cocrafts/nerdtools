local key = require("utils.key")

key.mode_keys("i", {

})

key.mode_keys("n", {
	-- Hop, fast navigation
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

	["<TAB>"] = ":BufferLineCycleNext<CR>",
	["<S-Tab>"] = ":BufferLineCyclePrev<CR>",

	["H"] = "Hzz",
	["L"] = "Lzz",
})

key.mode_keys("v", {
	["<"] = "<gv",
	[">"] = ">gv",
})
