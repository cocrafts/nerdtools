local M = {}

function M:init()
  require("engine.settings"):configure()
  require("engine.autocmds"):configure()
  require("engine.plugins"):configure()

  vim.g.colors_name = "stormone"
  vim.cmd "colorscheme stormone"

  require("engine.keymaps"):configure()
  require("engine.lsp"):setup()
end

return M
