local config = require("utils.config")

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
				local parsers = require("nvim-treesitter.parsers")
				local language = parsers.get_buf_lang(args.buf)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
				local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })

				if filetype == "neo-tree" or filetype == "toggleterm" or buftype == "nofile" or buftype == "terminal" then
					vim.o.statuscolumn = "%s"
				else
					vim.o.statuscolumn = "%s%=%{v:relnum?v:relnum:v:lnum} "
				end

				-- print(string.format("%s: %s", language, parsers.has_parser(language)))
				if parsers.has_parser(language) then
					vim.cmd("TSBufEnable highlight")
				end

				-- if filetype == "func" or filetype == "hurl" then
				-- 	vim.cmd("TSBufEnable highlight")
				-- end

				-- if filetype:sub(1, 4) == "json" then -- json, jsonc
				-- 	vim.opt.shiftwidth = config.json_indent_size
				-- else
				-- 	vim.opt.shiftwidth = config.indent_size
				-- end

				-- indent == "tabs" <- this mean using tab
				-- local indent = require("guess-indent").guess_from_buffer(args.buf)
				-- vim.opt.tabstop = config.indent_size
				-- vim.opt.shiftwidth = config.indent_size
			end,
		},
	},
	{
		"BufWritePre",
		{
			group = "goimports",
			desc = "Format and arrange Imports on save",
			pattern = "*.go",
			callback = function()
				require("go.format").goimports()
			end,
		},
		config.use_go == false,
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
	extension = {
		hx = "haxe",
		func = "func",
		hurl = "hurl",
		yamlfmt = "yaml",
		d2 = function()
			return "d2", function(bufnr)
				vim.bo[bufnr].commentstring = "# %s"
			end
		end,
	},
	filename = {
		["tsconfig.json"] = "jsonc",
		["apple-app-site-association"] = "jsonc",
	},
	pattern = {
		["%.env%.[%w_.-]+"] = "sh",
	},
})
