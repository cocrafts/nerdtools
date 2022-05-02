local M = {}

local config = {
  setup = {
    icons = {
      breadcrumb = "»",
      separator = "",
      group = " ",
    },
  },
  nopts = {
    mode = "n",
    prefix = "<leader>",
    buffer = nil,
    silent = true,
    noremap = true,
    nowait = true,
  },
  vopts = {
    mode = "v",
    prefix = "<leader>",
    buffer = nil,
    silent = true,
    noremap = true,
    nowait = true,
  },
  nmaps = {
    ["w"] = { "<cmd>w!<cr>", "save" },
    ["q"] = { "<cmd>q!<cr>", "quit" },
    ["/"] = { "<cmd>lua require('comment').toggle()<cr>", "comment" },
    ["c"] = { "<cmd>BufferClose!<CR>", "Close Buffer" },
    ["e"] = { "<cmd>NvimTreeToggle<CR>", "Explorer" },
    ["o"] = { "<cmd>Telescope find_files<CR>", "File search" },
    ["i"] = { "<cmd>Telescope live_grep<CR>", "Text search" },
    ["u"] = { "<cmd>Telescope oldfiles<CR>", "Recent files" },
    b = {
      name = "Buffer",
      j = { "<cmd>BufferPick<CR>", "Jump" },
      f = { "<cmd>Telescope buffers<CR>", "Find" },
      w = { "<cmd>BufferWipeout<CR>", "Wipeout" },
      e = { "<cmd>BufferCloseAllButCurrent<CR>", "Close all but current" },
      h = { "<cmd>BufferCloseBuffersLeft<CR>", "Close all to the left" },
      l = { "<cmd>BufferCloseBuffersRight<CR>", "Close all to the right" },
    },
    T = {
      name = "Treesitter",
      i = { ":TSConfigInfo<CR>", "Info" },
      h = { "<cmd>TSHighlightCapturesUnderCursor<CR>", "Highlight under cursor" },
      p = { "<cmd>TSPlaygroundToggle<CR>", "Playground" },
    },
    p = {
      name = "Packer",
      c = { "<cmd>PackerCompile<CR>", "Compile" },
      i = { "<cmd>PackerInstall<CR>", "Install" },
      s = { "<cmd>PackerSync<CR>", "Sync" },
      S = { "<cmd>PackerStatus<CR>", "Status" },
      u = { "<cmd>PackerUpdate<CR>", "Update" },
    },
    f = {
      name = "Finder",
      f = { "<cmd>Telescope find_files<CR>", "File search" },
      s = { "<cmd>Telescope live_grep<CR>", "Live grep search" },
      h = { "<cmd>Telescope help_tags<CR>", "Help tags" },
      r = { "<cmd>Telescope registers<CR>", "Registers" },
      k = { "<cmd>Telescope keymaps<CR>", "Keymaps" },
      c = { "<cmd>Telescope commands<CR>", "Commands" },
      m = { "<cmd>Telescope man_pages<CR>", "Man pages" },
    },
    G = {
      name = "Git Fugitive",
      s = { "<cmd>G<CR>", "Status" },
      c = { "<cmd>G commit<CR>", "Commit" },
      p = { "<cmd>G push<CR>", "Push" },
    },
    g = {
      name = "Git",
      j = { "<cmd>lua require('gitsigns').next_hunk()<CR>", "Next hunk" },
      k = { "<cmd>lua require('gitsigns').prev_hunk()<CR>", "Previous hunk" },
      l = { "<cmd>lua require('gitsigns').blame_line()<CR>", "Blame" },
      p = { "<cmd>lua require('gitsigns').preview_hunk()<CR>", "Preview hunk" },
      r = { "<cmd>lua require('gitsigns').reset_hunk()<CR>", "Reset hunk" },
      R = { "<cmd>lua require('gitsigns').reset_buffer()<CR>", "Reset buffer" },
      s = { "<cmd>lua require('gitsigns').stage_hunk()<CR>", "Stage hunk" },
      u = { "<cmd>lua require('gitsigns').undo_stage_hunk()<CR>", "Undo stage hunk" },
      o = { "<cmd>Telescope git_status<CR>", "Open changed file" },
      b = { "<cmd>Telescope git_branches<CR>", "Checkout branch" },
      c = { "<cmd>Telescope git_commits<CR>", "Checkout commit" },
      C = { "<cmd>Telescope git_bcommits<CR>", "Checkout commit (current file)" },
      d = { "<cmd>Gitsigns diffthis HEAD<CR>", "Git diff" },
    },
    l = {
      name = "LSP",
      d = { "<cmd>Telescope lsp_document_diagnostics<CR>", "Document Dianogstics" },
      D = { "<cmd>Telescope lsp_workspace_diagnostics<CR>", "Workspace Dianogstics" },
      f = { "<cmd>lua vim.lsp.buf.formatting()<CR>", "Format" },
      i = { "<cmd>LspInfo<CR>", "Info" },
      I = { "<cmd>LspInstallInfo<CR>", "Installer Info" },
      j = { "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", "Next Dianogstics" },
      k = { "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", "Previous Dianogstics" },
      l = { "<cmd>lua vim.lsp.codelens.run()<CR>", "CodeLens Action" },
      r = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
      s = { "<cmd>Telescope lsp_document_symbols<CR>", "Document Symbols" },
      S = { "<cmd>Telescope lsp_workspace_symbols<CR>", "Workspace symbols" },
    }
  },
  vmaps = {

  },
}

M.setup = function()
  local wk = require("which-key")

  wk.setup(config.setup)
  wk.register(config.nmaps, config.nopts)
  -- wk.register(config.vmaps, config.vopts)
end

return M
