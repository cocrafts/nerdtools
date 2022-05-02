local M = {}
local utils = require("engine.lsp.utils")
local providers = {
  sumneko_lua = require("engine.lsp.providers.sumneko-lua"),
  tsserver = require("engine.lsp.providers.tsserver"),
  terraformls = require("engine.lsp.providers.terraformls"),
}

M.setup = function()
  vim.g.coq_settings = utils.coq_settings

  for name, options in pairs(providers) do
    utils.configure_server(name, options)
  end

  require("engine.lsp.null-ls"):setup()
end

return M

