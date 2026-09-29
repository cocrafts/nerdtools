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

	-- Tailwind CSS LSP starts only in projects with a Tailwind config.
	vim.lsp.config("tailwindcss", {
		settings = {
			tailwindCSS = {
				experimental = {
					classRegex = {
						-- Standard patterns
						{ "class:\\s*([^=]+)",                    "[\"'`]([^\"'`]*).*?[\"'`]" },
						{ "class=\\s*[\"'`]([^\"'`]*).*?[\"'`]",  "[\"'`]([^\"'`]*).*?[\"'`]" },
						{ ":class=\\s*[\"'`]([^\"'`]*).*?[\"'`]", "[\"'`]([^\"'`]*).*?[\"'`]" },
					},
				},
				includeLanguages = {
					svelte = "html",
					heex = "html",    -- Phoenix LiveView support
					eex = "html",
					elixir = "html",
				},
				validate = true,
			},
		},
		filetypes = {
			"html",
			"heex",
			"eex",
			"elixir",
			"svelte",
			"javascriptreact",
			"typescriptreact",
		},
		root_markers = {
			"tailwind.config.js",
			"tailwind.config.ts",
			"tailwind.config.cjs",
			"tailwind.config.mjs",
		},
	})
end

return M
