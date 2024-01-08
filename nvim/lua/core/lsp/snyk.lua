local config = require("utils.config")
local M = {}

M.configure = function(lspconfig)
	local org = os.getenv("SNYK_ORG")
	local token = os.getenv("SNYK_TOKEN")

	if config.use_snyk and org ~= nil and token ~= nil then
		lspconfig.snyk_ls.setup({
			init_options = {
				organization = org,
				token = token,
				integrationName = "nvim",
				activateSnykCode = "true",
				enableTrustedFoldersFeature = "false",
				activateSnykCodeSecurity = "true",
				activateSnykCodeQuality = "true",
			},
		})
	end
end

return M
