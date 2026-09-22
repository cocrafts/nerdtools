local M = {}

M.configure = function()
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	vim.lsp.config("html", {
		capabilities = capabilities,
	})
		vim.lsp.enable("html")

	vim.lsp.config("svelte", {
		filetypes = { "svelte" },
		root_markers = { "svelte.config.js", ".git" },
	})
		vim.lsp.enable("svelte")

	vim.lsp.config("cssls", {
		capabilities = capabilities,
	})
		vim.lsp.enable("cssls")

	vim.lsp.config("tailwindcss", {
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
		root_markers = {
			"tailwind.config.js",
			"tailwind.config.ts",
			"tailwind.config.cjs",
			"tailwind.config.mjs",
			"postcss.config.js",
			"postcss.config.ts",
		},
	})
		vim.lsp.enable("tailwindcss")
end

return M
