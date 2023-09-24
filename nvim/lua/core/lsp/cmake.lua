local coq = require("coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.neocmake.setup(coq.lsp_ensure_capabilities({}))
end

return M
