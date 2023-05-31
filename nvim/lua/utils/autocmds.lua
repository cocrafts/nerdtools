local definitions = {
	{
		{ "BufRead", "BufWinEnter", "BufNewFile" },
		{
			group = "_file_opened",
			nested = true,
			callback = function(args)
				local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })

				if not (vim.fn.expand "%" == "" or buftype == "nofile") then
					vim.api.nvim_del_augroup_by_name "_file_opened"
					vim.cmd "do User FileOpened"
				end
			end,
		},
	},
	{
		"LspAttach",
		{
			group = "LspAttach_inlayhints",
			desc = "Inlay Hints if possible",
			callback = function(args)
				if not (args.data and args.data.client_id) then return end

				local bufnr = args.buf
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				require("lsp-inlayhints").on_attach(client, bufnr)
			end,
		}
	}
}

for _, entry in ipairs(definitions) do
	local event = entry[1]
	local opts = entry[2]

	if type(opts.group) == "string" and opts.group ~= "" then
		local exists, _ = pcall(vim.api.nvim_get_autocomds, { group = opts.group })

		if not exists then
			vim.api.nvim_create_augroup(opts.group, {})
		end
	end

	vim.api.nvim_create_autocmd(event, opts)
end