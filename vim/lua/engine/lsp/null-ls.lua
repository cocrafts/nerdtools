local M = {}
local buf_map = require("engine.utils").buf_map

M.setup = function()
  require("null-ls").config({

  })

  require("lspconfig")["null-ls"].setup({
    on_attach = function(client, bufnr)
      vim.cmd("command! LspDef lua vim.lsp.buf.definition()")
      vim.cmd("command! LspFormatting lua vim.lsp.buf.formatting()")
      vim.cmd("command! LspCodeAction lua vim.lsp.buf.code_action()")
      vim.cmd("command! LspHover lua vim.lsp.buf.hover()")
      vim.cmd("command! LspRename lua vim.lsp.buf.rename()")
      vim.cmd("command! LspRefs lua vim.lsp.buf.references()")
      vim.cmd("command! LspTypeDef lua vim.lsp.buf.type_definition()")
      vim.cmd("command! LspImplementation lua vim.lsp.buf.implementation()")
      vim.cmd("command! LspDiagPrev lua vim.lsp.buf.goto_prev()")
      vim.cmd("command! LspDiagNext lua vim.lsp.buf.goto_next()")
      vim.cmd("command! LspDiagLine lua vim.lsp.buf.show_line_diagnostics()")
      vim.cmd("command! LspSignatureHelp lua vim.lsp.buf.signature_help()")

      buf_map(bufnr, "n", "gd", ":LspDef<CR>")
      buf_map(bufnr, "n", "gr", ":LspRename<CR>")
      buf_map(bufnr, "n", "gy", ":LspTypeDef<CR>")
      buf_map(bufnr, "n", "K", ":LspHover<CR>")
      buf_map(bufnr, "n", "[a", ":LspDiagPrev<CR>")
      buf_map(bufnr, "n", "]a", ":LspDiagNext<CR>")
      buf_map(bufnr, "n", "ga", ":LspCodeAction<CR>")
      buf_map(bufnr, "n", "<Leader>a", ":LspDiagLine<CR>")
      buf_map(bufnr, "n", "<C-x><C-x>", ":LspSignatureHelp<CR>")

      if client.resolved_capabilities.document_formatting then
        vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()")
      end
    end
  })
end

return M
