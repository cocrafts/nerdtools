local M = {}

M.configure_server = function(server_name, options)
  local function ensure_installed(server)
    if server:is_installed() then
      return true
    end

    server:install()
    vim.schedule(function()
      vim.cmd [[LspStart]]
    end)
  end

  local coq = require("coq")
  local ok, server = require("nvim-lsp-installer.servers").get_server(server_name)
  local server_setup = coq.lsp_ensure_capabilities(options.setup)

  if ok and ensure_installed(server) then
    server:setup(server_setup)
  else
    require("lspconfig")[server_name].setup(server_setup)
  end

  -- vim.cmd [[ do User LspAttachBuffers ]]
end

M.coq_settings = {
  auto_start = "shut-up",
  keymap = {
    recommended = false,
    jump_to_mark = '<C-o>',
  },
  display = {
    ghost_text = {
      enabled = false,
      context = { "  ", "" },
    },
  },
  clients = {
    tabnine = { enabled = true }
  },
}

return M
