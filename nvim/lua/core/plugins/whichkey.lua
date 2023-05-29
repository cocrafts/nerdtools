local M = {}

local config = {
	setup = {
		icons = {
			breadcrumb = "»",
			separator = "",
			group = " ",
		},
	},
	nopts = {
		mode = "n",
		prefix = "<leader>",
		buffer = nil,
		silent = true,
		noremap = true,
		nowait = true,
	},
	vopts = {
		mode = "v",
		prefix = "<leader>",
		buffer = nil,
		silent = true,
		noremap = true,
		nowait = true,
	},
	nmaps = {
		["w"] = { "<cmd>w!<cr>", "save" },
		["q"] = { "<cmd>q!<cr>", "quit" },
		["/"] = { "<cmd>lua require('comment').toggle()<cr>", "comment" },
		["c"] = { "<cmd>BufferClose!<CR>", "Close Buffer" },
		["e"] = { "<cmd>NvimTreeToggle<CR>", "Explorer" },
		["o"] = { "<cmd>Telescope find_files<CR>", "File search" },
		["i"] = { "<cmd>Telescope live_grep<CR>", "Text search" },
		["u"] = { "<cmd>Telescope oldfiles<CR>", "Recent files" },
		p = {
			name = "Packer",
			c = { "<cmd>PackerCompile<CR>", "Compile" },
			i = { "<cmd>PackerInstall<CR>", "Install" },
			s = { "<cmd>PackerSync<CR>", "Sync" },
			S = { "<cmd>PackerStatus<CR>", "Status" },
			u = { "<cmd>PackerUpdate<CR>", "Update" },
		},
	},
}

M.configure = function()
	local whichkey = require("which-key")

	whichkey.setup(config.setup)
	whichkey.register(config.nmaps, config.nopts)
end

return M
