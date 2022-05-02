local M = {}

local config = {
  setup = {
    open_onsetup = false,
    auto_close = true,
    open_on_tab = true,
    update_cwd = true,
    ignore_ft_on_setup = { "startify", "dashboard" },
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
    view = {
      width = 34,
      side = "left",
      auto_resize = false,
      mappings = {
        custom_only = false,
      },
    },
    filters = {
      dotfiles = true,
    },
  },
  ignore = { ".git", "node_modules", ".cache", ".idea" },
  icons = {
    default = "",
    symlink = "",
    git = {
      unstaged = "",
      staged = "s",
      unmerged = "",
      renamed = "➜",
      untracked = "u",
      deleted = "",
      ignored = "◌",
    },
    folder = {
      arrow_open = "",
      arrow_closed = "",
      default = "",
      open = "",
      empty = "",
      empty_open = "",
      symlink = "",
      symlink_open = "",
    },
  },
  show_icons = {
    git = 0,
    folders = 1,
    files = 1,
    folder_arrows = 1,
    tree_width = 34,
  },
}

M.setup = function()
  vim.g.nvim_tree_icons = config.icons
  vim.g.nvim_tree_show_icons = config.show_icons
  vim.g.nvim_tree_git_hl = 1
  vim.g.nvim_tree_indent_markers = 1
  vim.g.nvim_tree_root_folder_modifier = table.concat { ":t:gs?$?/..", string.rep(" ", 1000), "?:gs?^??" }

  local tree = require("nvim-tree.view")
  local tree_open = tree.open
  tree.open = function()
    M.on_open()
    tree_open()
  end

  vim.cmd "au WinClosed * lua require('engine.plugins.nvimtree').on_close()"

  require("nvim-tree").setup(config.setup)
end

function M.on_open()
  if package.loaded["bufferline.state"] then
    require("bufferline.state").set_offset(35, "")
  end
end

function M.on_close()
  local buf = tonumber(vim.fn.expand "<abuf>")
  local ft = vim.api.nvim_buf_get_option(buf, "filetype")
  if ft == "NvimTree" and package.loaded["bufferline.state"] then
    require("bufferline.state").set_offset(0)
  end
end

return M
