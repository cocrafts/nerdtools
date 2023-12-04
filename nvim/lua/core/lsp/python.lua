local coq = require("core.coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.pyright.setup(coq.lsp_ensure_capabilities({
		formatter = "auto",
	}))
end

return M
