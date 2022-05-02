local M = {}

M.configure = function()
  local default_options = {
    backup = false, -- creates a backup file
    clipboard = "unnamedplus",
    cmdheight = 1,
    colorcolumn = "99999", -- fix indentline
    completeopt = { "menuone", "noselect" },
    conceallevel = 0,
    fileencoding = "utf-8",
    foldmethod = "manual",
    foldexpr = "",
    guifont = "monospace:h17",
    hidden = true,
    hlsearch = true, -- highlight all matches on previous search pattern
    ignorecase = true, -- ignore case when search
    smartcase = true,
    mouse = "a",
    pumheight = 10,
    showmode = false,
    swapfile = false, -- create swapfile
    termguicolors = true, -- set term gui colors
    timeoutlen = 100, -- time to wait for mapped sequence to complete
    title = true, -- show buffer name in window title
    -- undodir =
    undofile = true, -- enable persistent undo
    updatetime = 250, -- faster completion
    writebackup = false, -- if file being edited by another program
    expandtab = true, -- convert tabs to spaces
    shiftwidth = 2, -- number of spaces inserted for each indentation
    tabstop = 2, -- insert 2 spaces for a tab
    smartindent = true,
    cursorline = true, -- highlight current line
    number = true, -- show line numbers
    relativenumber = true, -- show relative numbers
    numberwidth = 4,
    signcolumn = "yes", -- always show sign column, avoid text being shifted all the time
    wrap = false, -- wrap too long line
    spell = false,
    spelllang = "en",
    scrolloff = 8,
    sidescrolloff = 8,
  }

  vim.opt.shortmess:append "c"

  for k, v in pairs(default_options) do
    vim.opt[k] = v
  end
end

-- M.load_commands = function()
--   local cmd = vim.cmd
-- end

return M
