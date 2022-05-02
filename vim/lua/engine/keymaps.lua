local M = {}
local utils = require("engine.utils")

M.configure = function()
  vim.g.mapleader = " "

  utils.mode_keys("i", {
    -- MacOS movement
    ["S4"] = "<ESC>_i", -- cmd+left to start of line
    ["S5"] = "<ESC>$a", -- cmd+right to end of line

    -- ["kj"] = "<ESC>",
  })

  utils.mode_keys("n", {
    -- MacOS word movement
    ["S4"] = "_i", -- cmd+left to start of line
    ["S5"] = "$a", -- cmd+right to end of line
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

    ["<TAB>"] = ":BufferNext<CR>",
    ["<S-Tab>"] = ":BufferPrevious<CR>",

    ["H"] = "Hzz",
    ["L"] = "Lzz",
  })

  utils.mode_keys("v", {
    ["<"] = "<gv",
    [">"] = ">gv",
  })
end

return M
