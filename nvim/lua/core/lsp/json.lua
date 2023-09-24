local coq = require("coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.jsonls.setup(coq.lsp_ensure_capabilities({}))
end

return M
