local M = {}

local options = {

}

M.configure = function()
	local telescope = require("telescope")

	---@diagnostic disable-next-line: redundant-parameter
	telescope.setup(options)
	telescope.load_extension("fzf")
end

return M
