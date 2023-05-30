local M = {}

M.configure = function()
	local telescope = require("telescope")

	telescope.load_extension("fzf")
end

return M
