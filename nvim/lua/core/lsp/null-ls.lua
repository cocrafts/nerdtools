local M = {}
local config = require("utils.config")
local null = require("utils.null")

local conf_path = function(suffix)
	return vim.fn.expand(string.format("~/nerdtools/conf/%s", suffix))
end

M.configure = function()
	local nls = require("null-ls")
	local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
	local sources = {
		nls.builtins.formatting.stylua,
		-- nls.builtins.formatting.zigfmt,
		-- nls.builtins.formatting.rustfmt,
		nls.builtins.formatting.csharpier,
		nls.builtins.diagnostics.revive,
		nls.builtins.formatting.golines.with({
			extra_args = {
				"--max-len=180",
				"--base-formatter=gofumpt",
			},
		}),

		nls.builtins.formatting.eslint_d,
		nls.builtins.diagnostics.eslint_d,
		null.formatting.jq,

		nls.builtins.formatting.shfmt,
		nls.builtins.diagnostics.stylelint,
	}

	if config.use_strict_spell_checker then
		local diagnostics = nls.builtins.diagnostics.cspell.with({
			extra_args = { string.format("--config=%s", conf_path("spell.json")) },
		})

		local actions = nls.builtins.code_actions.cspell.with({
			config = {
				find_json = function()
					conf_path("spell.json")
				end,
				on_success = function(cspell_config_file)
					-- format the cspell config file
					os.execute(
						string.format(
							"cat %s | jq -S '.words |= sort' | tee %s > /dev/null",
							cspell_config_file,
							cspell_config_file
						)
					)
				end,
			},
		})

		table.insert(sources, diagnostics)
		table.insert(sources, actions)
	else
		table.insert(
			sources,
			nls.builtins.diagnostics.typos.with({
				extra_args = { string.format("--config=%s", conf_path("typos.toml")) },
			})
		)
	end

	nls.setup({
		sources = sources,
		debounce = 1000,
		default_timeout = 5000,
		on_attach = function(client, bufnr)
			if client.supports_method("textDocument/formatting") then
				vim.api.nvim_clear_autocmds({
					group = augroup,
					buffer = bufnr,
				})

				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					callback = function()
						vim.lsp.buf.format({ bufnr = bufnr })
					end,
				})
			end
		end,
	})
end

return M
