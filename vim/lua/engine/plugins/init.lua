local M = {}

M.configure = function()
  local install_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

  if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    vim.fn.system { "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path }
    vim.cmd "packadd packer.nvim"
  end

  local packer_ok, packer = pcall(require, "packer")
  if not packer_ok then
    return
  end

  local plugins = require("engine.packers")

  packer.init({
    display = {
      open_fn = function()
        return require("packer.util").float({ border = "rounded" })
      end
    },
  })

  packer.startup(function(use)
    for _, plugin in ipairs(plugins) do
      use(plugin)
    end
  end)
end

return M
