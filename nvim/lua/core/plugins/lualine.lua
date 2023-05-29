local M = {}

local config = {
	setup = {
		theme = "tokyonight-night",
		options = {
			icons_enabled = true,
		},
		sections = {
			lualine_a = {
				{ 'filename', path = 1 }
			}
		}
	}
}

M.configure = function()
	require("lualine").setup(config.setup)
end

return M
