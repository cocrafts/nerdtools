local cmd_resolver = require("null-ls.helpers.command_resolver")
local h = require("null-ls.helpers")
local methods = require("null-ls.methods")
local u = require("null-ls.utils")

local M = {}
local FORMATTING = methods.internal.FORMATTING
local DIAGNOSTICS = methods.internal.DIAGNOSTICS

M.format = h.make_builtin({
	name = "eslint_d",
	meta = {
		url = "https://github.com/mantoni/eslint_d.js/",
		description = "Like ESLint, but faster.",
		notes = {
			"Once spawned, the server will continue to run in the background. This is normal and not related to null-ls. You can stop it by running `eslint_d stop` from the command line.",
		},
	},
	method = FORMATTING,
	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"vue",
	},
	generator_opts = {
		command = "eslint_d",
		args = { "--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME" },
		to_stdin = true,
	},
	factory = h.formatter_factory,
})

local handle_eslint_output = function(params)
	params.messages = params.output and params.output[1] and params.output[1].messages or {}
	if params.err then
		table.insert(params.messages, { message = params.err })
	end

	local parser = h.diagnostics.from_json({
		attributes = {
			_fix = "fix",
			severity = "severity",
		},
		severities = {
			h.diagnostics.severities["warning"],
			h.diagnostics.severities["error"],
		},
		adapters = {
			{
				user_data = function(entries)
					return { fixable = not not entries._fix }
				end,
			},
		},
	})

	return parser({ output = params.messages })
end

M.diagnostics = h.make_builtin({
	name = "eslint_d",
	meta = {
		url = "https://github.com/mantoni/eslint_d.js/",
		description = "Like ESLint, but faster.",
		notes = {
			"Once spawned, the server will continue to run in the background. This is normal and not related to null-ls. You can stop it by running `eslint_d stop` from the command line.",
		},
	},
	method = DIAGNOSTICS,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
	generator_opts = {
		command = "eslint_d",
		args = { "-f", "json", "--stdin", "--stdin-filename", "$FILENAME" },
		to_stdin = true,
		format = "json_raw",
		check_exit_code = function(code)
			return code <= 1
		end,
		use_cache = true,
		on_output = handle_eslint_output,
		dynamic_command = cmd_resolver.from_node_modules(),
		cwd = h.cache.by_bufnr(function(params)
			return u.cosmiconfig("eslint", "eslintConfig")(params.bufname)
		end),
	},
	factory = h.generator_factory,
})

return M
