local coq = require("coq")
local M = {}

M.configure = function(lspconfig)
	lspconfig.ruby_ls.setup(coq.lsp_ensure_capabilities({
		formatter = "auto",
	}))
end

return M
