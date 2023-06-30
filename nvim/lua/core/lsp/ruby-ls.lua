local M = {}

local options = {
	formatter = "auto",
}

M.configure = function(lspconfig)
	lspconfig.ruby_ls.setup()
end

return M
