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
		"BufWritePost",
		{
			group = "LspFormattingGroup",
			desc = "Format file on save",
			callback = function(args)
				local efm = vim.lsp.get_clients({ name = "efm" })
				if vim.tbl_isempty(efm) then
					return
				end
				vim.lsp.buf.format({ name = "efm" })
				vim.api.nvim_buf_call(args.buf, function()
					vim.cmd("w")
				end)
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
					local is_ignored = helper.valueExists(filetype, { "go", "rust" })

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
