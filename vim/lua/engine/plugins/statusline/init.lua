local M = {}
local styles = require("engine.plugins.statusline.styles")

M.setup = function()
  require("lualine").setup(styles.stormone)
end

return M

