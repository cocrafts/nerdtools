local M = {}

local config = {
  setup = {
    open_on_tab = true,
    update_cwd = true,
    update_focused_file = {
      enable = true,
      update_cwd = false,
    },
    diagnostics = {
      enable = true,
      icons = {
        hint = "",
        info = "",
        warning = "",
        error = "",
      },
    },
    renderer = {
      group_empty = true,
    },
    view = {
      width = 34,
      side = "left",
      mappings = {
        custom_only = false,
      },
    },
    filters = {
      dotfiles = true,
    },
  },
  ignore = { ".git", "node_modules", ".cache", ".idea" },
}

M.setup = function()
  local nvim_tree_events = require('nvim-tree.events')
  local bufferline_api = require('bufferline.api')

  local function get_tree_size()
    return require("nvim-tree.view").View.width
  end

  nvim_tree_events.subscribe("TreeOpen", function()
    bufferline_api.set_offset(get_tree_size())
  end)

  nvim_tree_events.subscribe("Resize", function()
    bufferline_api.set_offset(get_tree_size())
  end)

  nvim_tree_events.subscribe('TreeClose', function()
    bufferline_api.set_offset(0)
  end)

  require("nvim-tree").setup(config.setup)
end

return M
