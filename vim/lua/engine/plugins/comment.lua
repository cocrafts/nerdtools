local M = {}

M.setup = function()
  require("Comment").setup {
    padding = true,
    ignore = "^$",
    mappings = {
      basic = true, -- gcc, gcb, gc[count]{motion} and gb[count]{motion}
      extra = false, -- g>, g<, g>[count]{motion} and g<[count]{motion}
    },
    toggler = {
      line = "gcc",
      block = "gcb",
    },
    opleader = {
      line = "gc",
      block = "gb",
    },
  }
end

return M
