-- scoop shim spawns cost ~20-27ms extra each (nvim libuv bench 2026-09-21:
-- rg 53→26ms, fzf 119→97ms); resolve the hot search binaries directly.
if vim.fn.has("win32") == 1 then
	local direct = {}
	for _, app in ipairs({ "ripgrep", "fd", "fzf" }) do
		local dir = vim.fn.expand("~/scoop/apps/" .. app .. "/current")
		if vim.fn.isdirectory(dir) == 1 then
			table.insert(direct, dir)
		end
	end
	if #direct > 0 then
		vim.env.PATH = table.concat(direct, ";") .. ";" .. vim.env.PATH
	end
end
require("utils.settings")
require("utils.commands")
require("utils.autocmds")
require("utils.keymaps")
require("core").initialize()
require("themes")

-- Setup Claude integration (needs to run early for lock file)
-- require("core.claude").setup()
