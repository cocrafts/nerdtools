local coq = require("coq")
local M = {}

-- Configure instruction:use this instruction: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#omnisharp
-- 1. Install dotnet-sdk: https://dotnet.microsoft.com/download
-- 2. Download roslyn release: https://github.com/OmniSharp/omnisharp-roslyn/releases
-- 3. chmod 755 ./run for downloaded roslyn build
-- 4. Also make sure mono installed: https://www.mono-project.com/download/stable/

M.configure = function(lspconfig)
	lspconfig.omnisharp.setup(coq.lsp_ensure_capabilities({
		cmd = { "/Users/le/Sources/omnisharp/run", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
		handlers = {
			["textDocument/definition"] = require("omnisharp_extended").handler,
		},
		enable_editorconfig_support = true,
		enable_roslyn_analyzers = true,
	}))
end

return M
