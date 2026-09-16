local M = {}

M.configure = function()
	require("metascript").setup({
		-- lsp = {
		-- 	cmd = { "bun", "/Users/le/metascript/recompiler/bun/run.ts", "lsp" },
		-- 	-- cmd = { "/Users/le/metascript/recompiler/bin/nogc", "lsp" },
		-- },
	})
end

return M
