local M = {}

local groups = {
  general_settings = {
    {
      "TextYankPost",
      "*",
      "lua require('vim.highlight').on_yank({ higroup = 'Search', timeout = 200 })",
    },
  },
}

M.configure = function()
  for group_name, definition in pairs(groups) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")

    for _, def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten { "autocmd", def }, " ")
      vim.cmd(command)
    end

    vim.cmd("augroup END")
  end
end

return M
