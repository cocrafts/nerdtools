local M = {}

local options = {
	ensure_installed = {
		"rust",
		"lua",
		"vim"
	},
}

M.configure = function()
	local ok, configs = pcall(require, "nvm-treesitter.configs")
	if not ok then return end

	configs.setup(options)
end

return M
