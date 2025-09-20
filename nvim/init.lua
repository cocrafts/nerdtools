require("utils.settings")
require("utils.commands")
require("utils.autocmds")
require("utils.keymaps")
require("core").initialize()
require("themes")

-- Setup Claude integration (needs to run early for lock file)
require("core.claude").setup()
