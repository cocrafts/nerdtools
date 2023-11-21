local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local plugins = require("utils.plugins")

local M = {}

M.initialize = function()
	-- Auto-install lazy.nvim if not present
	if not vim.loop.fs_stat(lazypath) then
		print("Installing lazy.nvim....")

		vim.fn.system({
			"git",
			"clone",
			"--filter=blob:none",
			"https://github.com/folke/lazy.nvim.git",
			"--branch=stable", -- latest stable release
			lazypath,
		})
	end

	vim.opt.rtp:prepend(lazypath)

	require("lazy").setup({
		spec = plugins,
		defaults = {
			lazy = false,
			version = false,
		},
		checker = { enabled = true },
		performance = {
			rtp = {
				disabled_plugins = {
					"gzip",
					"tutor",
					"tohtml",
					"tarPlugin",
					"zipPlugin",
					"netrwPlugin",
				},
			},
		},
	})
end

return M
