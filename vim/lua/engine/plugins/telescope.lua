local M = {}

local config = {
  defaults = {
    pickers = {
      find_files = {
        find_command = { "fd", "--type=file", "--hidden", "--smart-case" },
      },
      live_grep = {
        only_sort_text = true, -- don't include filename in search result
      },
    },
  },
  color_devicons = true,
  set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil
  extensions = {
    fzf = {
      fuzzy = true, -- false will only do exact matching
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case", -- produce best result
    },
  },
}

M.setup = function()
  local telescope = require("telescope")

  telescope.setup(config)
  telescope.load_extension("fzf")
end

return M
