local M = {}
local cmp = require("cmp")

local formatting = {
    kind_icons = {
    Class = " ",
    Color = " ",
    Constant = "ﲀ ",
    Constructor = " ",
    Enum = "練",
    EnumMember = " ",
    Event = " ",
    Field = " ",
    File = "",
    Folder = " ",
    Function = " ",
    Interface = "ﰮ ",
    Keyword = " ",
    Method = " ",
    Module = " ",
    Operator = "",
    Property = " ",
    Reference = " ",
    Snippet = " ",
    Struct = " ",
    Text = " ",
    TypeParameter = " ",
    Unit = "塞",
    Value = " ",
    Variable = " ",
  },
  source_names = {
    nvim_lsp = "(LSP)",
    emoji = "(Emoji)",
    path = "(Path)",
    calc = "(Calc)",
    cmp_tabnine = "(Tabnine)",
    vsnip = "(Snippet)",
    luasnip = "(Snippet)",
    buffer = "(Buffer)",
  },
  duplicates = {
    buffer = 1,
    path = 1,
    nvim_lsp = 0,
    luasnip = 1,
  },
  duplicates_default = 0,
}

local config = {
  snippet = {
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body)
    end
  },
  formatting = {
    format = function(entry, vim_item)
      vim_item.kind = formatting.kind_icons[vim_item.kind]
      vim_item.menu = formatting.source_names[entry.source.name]
      vim_item.dup = formatting.duplicates[entry.source.name] or formatting.duplicates_default

      return vim_item
    end,
  },
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
  }, {
    { name = "buffer" },
  }),
  mapping = {
    ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
    ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
    ["<C-space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
    ["<C-y>"] = cmp.config.disable,
    ["<C-e>"] = cmp.mapping({
      i = cmp.mapping.close(),
      c = cmp.mapping.close(),
    }),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      -- local pilot = vim.fn["copilot#Accept"]()

      -- if pilot ~= "" then
      --   vim.api.nvim_feedkeys(pilot, "i", true)
      -- else
      if cmp.visible() then
        -- cmp.select_next_item({ cmp.SelectBehavior.Select })
        cmp.confirm({ select = true, behavior = cmp.SelectBehavior.Insert })
        -- cmp.select_next_item()
      else
        fallback()
      end
    end, { "i" })
  },
}

local cmdConfig = {
  sources = cmp.config.sources({
    { name = "path" },
  }, {
    { name = "cmdline" },
  }),
}

local searchConfig = {
  sources = {
    { name = "buffer" },
  },
}

M.setup = function()
  -- vim.g.copilot_no_tab_map = true
  -- vim.g.copilot_assume_mapped = true
  -- vim.g.copilot_tab_fallback = ""

  cmp.setup(config)
  -- cmp.setup.cmdline(":", cmdConfig)
  -- cmp.setup.cmdline("/", searchConfig)
end

return M

