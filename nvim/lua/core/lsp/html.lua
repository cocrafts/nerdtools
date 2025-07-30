local M = {}

M.configure = function(lspconfig)
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	lspconfig.html.setup({
		capabilities = capabilities,
	})

	lspconfig.svelte.setup({
		filetypes = { "svelte" },
		root_dir = lspconfig.util.root_pattern("svelte.config.js", ".git"),
	})

	lspconfig.cssls.setup({
		capabilities = capabilities,
	})

	lspconfig.tailwindcss.setup({
		settings = {
			tailwindCSS = {
				experimental = {
					classRegex = {
						{ "class:\\s*([^=]+)",                    "[\"'`]([^\"'`]*).*?[\"'`]" },
						{ "class=\\s*[\"'`]([^\"'`]*).*?[\"'`]",  "[\"'`]([^\"'`]*).*?[\"'`]" },
						{ ":class=\\s*[\"'`]([^\"'`]*).*?[\"'`]", "[\"'`]([^\"'`]*).*?[\"'`]" },
					},
				},
				includeLanguages = {
					typescript = "javascript",
					typescriptreact = "javascript",
					svelte = "html",
				},
				validate = true,
			},
		},
		filetypes = {
			"svelte",
			"html",
			"css",
			"javascript",
			"typescript",
			"javascriptreact",
			"typescriptreact",
		},
		root_dir = lspconfig.util.root_pattern(
			"tailwind.config.js",
			"tailwind.config.ts",
			"tailwind.config.cjs",
			"tailwind.config.mjs",
			"postcss.config.js",
			"postcss.config.ts"
		),
	})
end

return M
