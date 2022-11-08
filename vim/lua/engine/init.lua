local M = {}

function M:init()
  require("engine.settings"):configure()
  require("engine.autocmds"):configure()
  require("engine.plugins"):configure()

  -- recommended for nvim-tree
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
  vim.g.rust_recommended_style = 0

  vim.g.colors_name = "stormone"
  vim.cmd "colorscheme stormone"

  require("engine.keymaps"):configure()
  require("engine.lsp"):setup()
end

return M
