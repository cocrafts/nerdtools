local M = {}

local options = {

}

M.configure = function()
	require("mason").setup(options)
end

return M
