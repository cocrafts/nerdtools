local coq = require("core.coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.clangd.setup(coq.lsp_ensure_capabilities({}))
end

return M
