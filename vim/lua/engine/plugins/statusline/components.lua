local colors = require("engine.plugins.statusline.theme").colors

local conditions = {
  hide_in_width = function()
    return vim.fn.winwidth(0) > 80
  end
}

local diff_source = function()
  local gitsigns = vim.b.gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed,
    }
  end
end

local mode = {
  function()
    return " "
  end,
  padding = { left = 0, right = 0 },
  color = {},
  cond = nil,
}

local branch = {
  "b:gitsigns_head",
  icon = " ",
  color = { gui = "bold" },
  cond = conditions.hide_in_width,
}

local filename = {
  "filename",
  color = {},
  cond = nil,
}

local diff = {
  "diff",
  source = diff_source,
  symbols = { added = "  ", modified = "柳", removed = " " },
  diff_color = {
    added = { fg = colors.green },
    modified = { fg = colors.yellow },
    removed = { fg = colors.red },
  },
  color = {},
  cond = nil,
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_lsp" },
  symbols = { error = " ", warn = " ", info = " ", hint = " " },
  color = {},
  cond = conditions.hide_in_width,
}

local filetype = {
  "filetype",
  cond = conditions.hide_in_width,
  color = {},
}

local treesitter = {
  function()
    local b = vim.api.nvim_get_current_buf()
    if next(vim.treesitter.highlighter.active[b]) then
      return "  "
    end
    return ""
  end,
  color = { fg = colors.green },
  cond = conditions.hide_in_width,
}

local encoding = {
  "o:encoding",
  fmt = string.upper,
  color = {},
  cond = conditions.hide_in_width,
}

local scrollbar = {
  function()
    local current_line = vim.fn.line "."
    local total_lines = vim.fn.line "$"
    local chars = { "__", "▁▁", "▂▂", "▃▃", "▄▄", "▅▅", "▆▆", "▇▇", "██" }
    local line_ratio = current_line / total_lines
    local index = math.ceil(line_ratio * #chars)

    return chars[index]
  end,
  padding = { left = 0, right = 0, },
  color = { fg = colors.yellow, bg = colors.bg },
  cond = nil,
}

local lsp = {
  function()
    local buf_clients = vim.lsp.buf_get_clients()

    if next(buf_clients) == nil then
      return "LSP off"
    end

    -- local buf_ft = vim.bo.filetype
    local buf_client_names = {}

    for _, client in pairs(buf_clients) do
      if client.name ~= "null-ls" then
        table.insert(buf_client_names, client.name)
      end
    end

    return table.concat(buf_client_names, ", ")
  end,
  icon = "",
  color = {},
  cond = conditions.hide_in_width,
}

return {
  mode = mode,
  branch = branch,
  filename = filename,
  scrollbar = scrollbar,
  diff = diff,
  diagnostics = diagnostics,
  filetype = filetype,
  treesitter = treesitter,
  encoding = encoding,
  lsp = lsp,
}
