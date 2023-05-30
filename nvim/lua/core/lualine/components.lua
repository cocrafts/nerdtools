local colors = require("core.lualine.colors")
local conditions = require("core.lualine.conditions")

local diff_source = function()
	local gitsigns = vim.b.gitsigns_status_dict

	if gitsigns then
		return {
			added = gitsigns.added,
			modified = gitsigns.changed,
			removed = gitsigns.removed,
		}
	end
end
