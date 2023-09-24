local coq = require("core.coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.bashls.setup(coq.lsp_ensure_capabilities({}))
end

return M
