local config = require("utils.config")
local helper = require("utils.helper")

local definitions = {
	{
		{ "BufRead", "BufWinEnter", "BufNewFile" },
		{
			group = "_file_opened",
			nested = true,
			callback = function(args)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })

				if not (vim.fn.expand("%") == "" or buftype == "nofile") then
					vim.api.nvim_del_augroup_by_name("_file_opened")
					vim.cmd("do User FileOpened")
				end
			end,
		},
	},
	{
		"BufEnter",
		{
			group = "BufferEnter",
			desc = "Buffer Enter",
			callback = function(args)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
				local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })

				if filetype == "neo-tree" or filetype == "toggleterm" or buftype == "nofile" then
					vim.o.statuscolumn = "%s"
				else
					vim.o.statuscolumn = "%s%=%{v:relnum?v:relnum:v:lnum} "
				end

				if filetype == "func" then
					require("nvim-treesitter.highlight").attach(args.buf, "func")
				end

				local indent = require("guess-indent").guess_from_buffer(args.buf)

				if indent == "tabs" then
					vim.opt.tabstop = 2
					vim.opt.shiftwidth = 2
				else
					vim.opt.tabstop = 4
					vim.opt.shiftwidth = 4
				end
			end,
		},
	},
	{
		"LspAttach",
		{
			group = "UserLspConfig",
			desc = "Lsp and Inlayhints",
			callback = function(args)
				local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })

				if args.data and args.data.client_id then -- lsp-inlayhints
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					local is_ignored = helper.valueExists(filetype, { "rust" })

					if client ~= nil and is_ignored == false then
						require("lsp-inlayhints").on_attach(client, args.buf)
					end
				end
			end,
		},
		config.use_inlay_hints == false,
	},
	{
		"TextYankPost",
		{
			group = "_general_settings",
			pattern = "*",
			desc = "Highlight text on yank",
			callback = function()
				vim.highlight.on_yank({ higroup = "Search", timeout = 100 })
			end,
		},
	},
}

for _, entry in ipairs(definitions) do
	local event = entry[1]
	local opts = entry[2]
	local disabled = entry[3]

	if not disabled and type(opts.group) == "string" and opts.group ~= "" then
		local exists, _ = pcall(vim.api.nvim_get_autocmds, { group = opts.group })

		if not exists then
			vim.api.nvim_create_augroup(opts.group, {})
			vim.api.nvim_create_autocmd(event, opts)
		end
	end
end

vim.api.nvim_command("autocmd BufRead,BufNewFile Podfile set filetype=ruby")
vim.filetype.add({
	filename = {
		["tsconfig.json"] = "jsonc",
		["apple-app-site-association"] = "jsonc",
		[".yamlfmt"] = "yaml",
	},
	pattern = {
		["%.env%.[%w_.-]+"] = "sh",
	},
})
