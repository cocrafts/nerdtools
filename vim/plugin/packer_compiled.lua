-- Automatically generated packer.nvim plugin loader code

if vim.api.nvim_call_function('has', {'nvim-0.5'}) ~= 1 then
  vim.api.nvim_command('echohl WarningMsg | echom "Invalid Neovim version for packer.nvim! | echohl None"')
  return
end

vim.api.nvim_command('packadd packer.nvim')

local no_errors, error_msg = pcall(function()

_G._packer = _G._packer or {}
_G._packer.inside_compile = true

local time
local profile_info
local should_profile = false
if should_profile then
  local hrtime = vim.loop.hrtime
  profile_info = {}
  time = function(chunk, start)
    if start then
      profile_info[chunk] = hrtime()
    else
      profile_info[chunk] = (hrtime() - profile_info[chunk]) / 1e6
    end
  end
else
  time = function(chunk, start) end
end

local function save_profiles(threshold)
  local sorted_times = {}
  for chunk_name, time_taken in pairs(profile_info) do
    sorted_times[#sorted_times + 1] = {chunk_name, time_taken}
  end
  table.sort(sorted_times, function(a, b) return a[2] > b[2] end)
  local results = {}
  for i, elem in ipairs(sorted_times) do
    if not threshold or threshold and elem[2] > threshold then
      results[i] = elem[1] .. ' took ' .. elem[2] .. 'ms'
    end
  end
  if threshold then
    table.insert(results, '(Only showing plugins that took longer than ' .. threshold .. ' ms ' .. 'to load)')
  end

  _G._packer.profile_output = results
end

time([[Luarocks path setup]], true)
local package_path_str = "/Users/le/.cache/nvim/packer_hererocks/2.1.0-beta3/share/lua/5.1/?.lua;/Users/le/.cache/nvim/packer_hererocks/2.1.0-beta3/share/lua/5.1/?/init.lua;/Users/le/.cache/nvim/packer_hererocks/2.1.0-beta3/lib/luarocks/rocks-5.1/?.lua;/Users/le/.cache/nvim/packer_hererocks/2.1.0-beta3/lib/luarocks/rocks-5.1/?/init.lua"
local install_cpath_pattern = "/Users/le/.cache/nvim/packer_hererocks/2.1.0-beta3/lib/lua/5.1/?.so"
if not string.find(package.path, package_path_str, 1, true) then
  package.path = package.path .. ';' .. package_path_str
end

if not string.find(package.cpath, install_cpath_pattern, 1, true) then
  package.cpath = package.cpath .. ';' .. install_cpath_pattern
end

time([[Luarocks path setup]], false)
time([[try_loadstring definition]], true)
local function try_loadstring(s, component, name)
  local success, result = pcall(loadstring(s), name, _G.packer_plugins[name])
  if not success then
    vim.schedule(function()
      vim.api.nvim_notify('packer.nvim: Error running ' .. component .. ' for ' .. name .. ': ' .. result, vim.log.levels.ERROR, {})
    end)
  end
  return result
end

time([[try_loadstring definition]], false)
time([[Defining packer_plugins]], true)
_G.packer_plugins = {
  ["Comment.nvim"] = {
    config = { "\27LJ\2\nH\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\27engine.plugins.comment\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/Comment.nvim",
    url = "https://github.com/numToStr/Comment.nvim"
  },
  ["auto-save.nvim"] = {
    config = { "\27LJ\2\n7\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\14auto-save\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/auto-save.nvim",
    url = "https://github.com/Pocco81/auto-save.nvim"
  },
  ["barbar.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/barbar.nvim",
    url = "https://github.com/romgrk/barbar.nvim"
  },
  ["better-escape.nvim"] = {
    config = { "\27LJ\2\n;\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\18better_escape\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/better-escape.nvim",
    url = "https://github.com/max397574/better-escape.nvim"
  },
  ["copilot.vim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/copilot.vim",
    url = "https://github.com/github/copilot.vim"
  },
  ["coq.artifacts"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/coq.artifacts",
    url = "https://github.com/ms-jpq/coq.artifacts"
  },
  coq_nvim = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/coq_nvim",
    url = "https://github.com/ms-jpq/coq_nvim"
  },
  ["gitsigns.nvim"] = {
    config = { "\27LJ\2\nE\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\28engine.plugins.gitsigns\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/gitsigns.nvim",
    url = "https://github.com/lewis6991/gitsigns.nvim"
  },
  ["goto-preview"] = {
    config = { "\27LJ\2\nd\0\0\3\0\4\0\a6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\3\0B\0\2\1K\0\1\0\1\0\3\vheight\3\25\nwidth\3x\21default_mappings\2\nsetup\17goto-preview\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/goto-preview",
    url = "https://github.com/rmagatti/goto-preview"
  },
  ["hop.nvim"] = {
    config = { "\27LJ\2\n5\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\bhop\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/hop.nvim",
    url = "https://github.com/phaazon/hop.nvim"
  },
  ["indent-blankline.nvim"] = {
    config = { "\27LJ\2\nJ\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\29engine.plugins.blankline\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/indent-blankline.nvim",
    url = "https://github.com/lukas-reineke/indent-blankline.nvim"
  },
  ["lsp_signature.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/lsp_signature.nvim",
    url = "https://github.com/ray-x/lsp_signature.nvim"
  },
  ["lualine.nvim"] = {
    config = { "\27LJ\2\nK\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\30engine.plugins.statusline\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/lualine.nvim",
    url = "https://github.com/nvim-lualine/lualine.nvim"
  },
  ["null-ls.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/null-ls.nvim",
    url = "https://github.com/jose-elias-alvarez/null-ls.nvim"
  },
  ["nvim-autopairs"] = {
    config = { "\27LJ\2\nJ\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\29engine.plugins.autopairs\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-autopairs",
    url = "https://github.com/windwp/nvim-autopairs"
  },
  ["nvim-colorizer.lua"] = {
    config = { "\27LJ\2\n|\0\0\4\0\5\0\b6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\3\0005\3\4\0B\0\3\1K\0\1\0\1\0\a\rRRGGBBAA\2\vRRGGBB\2\bRGB\2\vcss_fn\2\bcss\2\vhsl_fn\2\vrgb_fn\2\1\2\0\0\6*\nsetup\14colorizer\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-colorizer.lua",
    url = "https://github.com/norcalli/nvim-colorizer.lua"
  },
  ["nvim-hlslens"] = {
    config = { "\27LJ\2\no\0\0\3\0\4\0\a6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\3\0B\0\2\1K\0\1\0\1\0\3\23nearest_float_when\valways\17nearest_only\2\14calm_down\2\nsetup\fhlslens\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/nvim-hlslens",
    url = "https://github.com/kevinhwang91/nvim-hlslens"
  },
  ["nvim-lastplace"] = {
    config = { "\27LJ\2\n�\1\0\0\4\0\b\0\v6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\4\0005\3\3\0=\3\5\0025\3\6\0=\3\a\2B\0\2\1K\0\1\0\30lastplace_ignore_filetype\1\5\0\0\14gitcommit\14gitrebase\bsvn\rhgcommit\29lastplace_ignore_buftype\1\0\1\25lastplace_open_folds\2\1\4\0\0\rquickfix\vnofile\thelp\nsetup\19nvim-lastplace\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/nvim-lastplace",
    url = "https://github.com/ethanholz/nvim-lastplace"
  },
  ["nvim-lsp-installer"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-lsp-installer",
    url = "https://github.com/williamboman/nvim-lsp-installer"
  },
  ["nvim-lsp-ts-utils"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-lsp-ts-utils",
    url = "https://github.com/jose-elias-alvarez/nvim-lsp-ts-utils"
  },
  ["nvim-lspconfig"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-lspconfig",
    url = "https://github.com/neovim/nvim-lspconfig"
  },
  ["nvim-spectre"] = {
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/nvim-spectre",
    url = "https://github.com/windwp/nvim-spectre"
  },
  ["nvim-tree.lua"] = {
    config = { "\27LJ\2\nI\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\28engine.plugins.nvimtree\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-tree.lua",
    url = "https://github.com/nvim-tree/nvim-tree.lua"
  },
  ["nvim-treesitter"] = {
    config = { "\27LJ\2\nG\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\30engine.plugins.treesitter\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-treesitter",
    url = "https://github.com/nvim-treesitter/nvim-treesitter"
  },
  ["nvim-ts-rainbow"] = {
    config = { "\27LJ\2\nv\0\0\4\0\6\0\t6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\4\0005\3\3\0=\3\5\2B\0\2\1K\0\1\0\frainbow\1\0\0\1\0\2\18extended_mode\2\venable\2\nsetup\28nvim-treesitter.configs\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-ts-rainbow",
    url = "https://github.com/p00f/nvim-ts-rainbow"
  },
  ["nvim-web-devicons"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/nvim-web-devicons",
    url = "https://github.com/nvim-tree/nvim-web-devicons"
  },
  ["onedark.vim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/onedark.vim",
    url = "https://github.com/joshdick/onedark.vim"
  },
  ["packer.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/packer.nvim",
    url = "https://github.com/wbthomason/packer.nvim"
  },
  playground = {
    loaded = false,
    needs_bufread = true,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/playground",
    url = "https://github.com/nvim-treesitter/playground"
  },
  ["plenary.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/plenary.nvim",
    url = "https://github.com/nvim-lua/plenary.nvim"
  },
  ["telescope-fzf-native.nvim"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/telescope-fzf-native.nvim",
    url = "https://github.com/nvim-telescope/telescope-fzf-native.nvim"
  },
  ["telescope.nvim"] = {
    config = { "\27LJ\2\nJ\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\29engine.plugins.telescope\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/telescope.nvim",
    url = "https://github.com/nvim-telescope/telescope.nvim"
  },
  ["trouble.nvim"] = {
    config = { "\27LJ\2\n9\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\0029\0\2\0004\2\0\0B\0\2\1K\0\1\0\nsetup\ftrouble\frequire\0" },
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/trouble.nvim",
    url = "https://github.com/folke/trouble.nvim"
  },
  ["vim-cursorword"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/vim-cursorword",
    url = "https://github.com/itchyny/vim-cursorword"
  },
  ["vim-fugitive"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/vim-fugitive",
    url = "https://github.com/tpope/vim-fugitive"
  },
  ["vim-matchup"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/vim-matchup",
    url = "https://github.com/andymass/vim-matchup"
  },
  ["vim-polyglot"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/vim-polyglot",
    url = "https://github.com/sheerun/vim-polyglot"
  },
  ["vim-sandwich"] = {
    loaded = false,
    needs_bufread = true,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/vim-sandwich",
    url = "https://github.com/machakann/vim-sandwich"
  },
  ["vim-wakatime"] = {
    loaded = true,
    path = "/Users/le/.local/share/nvim/site/pack/packer/start/vim-wakatime",
    url = "https://github.com/wakatime/vim-wakatime"
  },
  ["which-key.nvim"] = {
    config = { "\27LJ\2\nB\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\21engine.keywhichs\frequire\0" },
    loaded = false,
    needs_bufread = false,
    only_cond = false,
    path = "/Users/le/.local/share/nvim/site/pack/packer/opt/which-key.nvim",
    url = "https://github.com/folke/which-key.nvim"
  }
}

time([[Defining packer_plugins]], false)
-- Config for: better-escape.nvim
time([[Config for better-escape.nvim]], true)
try_loadstring("\27LJ\2\n;\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\18better_escape\frequire\0", "config", "better-escape.nvim")
time([[Config for better-escape.nvim]], false)
-- Config for: nvim-treesitter
time([[Config for nvim-treesitter]], true)
try_loadstring("\27LJ\2\nG\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\30engine.plugins.treesitter\frequire\0", "config", "nvim-treesitter")
time([[Config for nvim-treesitter]], false)
-- Config for: nvim-ts-rainbow
time([[Config for nvim-ts-rainbow]], true)
try_loadstring("\27LJ\2\nv\0\0\4\0\6\0\t6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\4\0005\3\3\0=\3\5\2B\0\2\1K\0\1\0\frainbow\1\0\0\1\0\2\18extended_mode\2\venable\2\nsetup\28nvim-treesitter.configs\frequire\0", "config", "nvim-ts-rainbow")
time([[Config for nvim-ts-rainbow]], false)
-- Config for: auto-save.nvim
time([[Config for auto-save.nvim]], true)
try_loadstring("\27LJ\2\n7\0\0\3\0\3\0\0066\0\0\0'\2\1\0B\0\2\0029\0\2\0B\0\1\1K\0\1\0\nsetup\14auto-save\frequire\0", "config", "auto-save.nvim")
time([[Config for auto-save.nvim]], false)
-- Config for: nvim-colorizer.lua
time([[Config for nvim-colorizer.lua]], true)
try_loadstring("\27LJ\2\n|\0\0\4\0\5\0\b6\0\0\0'\2\1\0B\0\2\0029\0\2\0005\2\3\0005\3\4\0B\0\3\1K\0\1\0\1\0\a\rRRGGBBAA\2\vRRGGBB\2\bRGB\2\vcss_fn\2\bcss\2\vhsl_fn\2\vrgb_fn\2\1\2\0\0\6*\nsetup\14colorizer\frequire\0", "config", "nvim-colorizer.lua")
time([[Config for nvim-colorizer.lua]], false)
-- Config for: nvim-autopairs
time([[Config for nvim-autopairs]], true)
try_loadstring("\27LJ\2\nJ\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\29engine.plugins.autopairs\frequire\0", "config", "nvim-autopairs")
time([[Config for nvim-autopairs]], false)
-- Config for: trouble.nvim
time([[Config for trouble.nvim]], true)
try_loadstring("\27LJ\2\n9\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\0029\0\2\0004\2\0\0B\0\2\1K\0\1\0\nsetup\ftrouble\frequire\0", "config", "trouble.nvim")
time([[Config for trouble.nvim]], false)
-- Config for: nvim-tree.lua
time([[Config for nvim-tree.lua]], true)
try_loadstring("\27LJ\2\nI\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\28engine.plugins.nvimtree\frequire\0", "config", "nvim-tree.lua")
time([[Config for nvim-tree.lua]], false)
-- Config for: lualine.nvim
time([[Config for lualine.nvim]], true)
try_loadstring("\27LJ\2\nK\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\30engine.plugins.statusline\frequire\0", "config", "lualine.nvim")
time([[Config for lualine.nvim]], false)
-- Config for: telescope.nvim
time([[Config for telescope.nvim]], true)
try_loadstring("\27LJ\2\nJ\0\0\3\0\3\0\a6\0\0\0'\2\1\0B\0\2\2\18\2\0\0009\0\2\0B\0\2\1K\0\1\0\nsetup\29engine.plugins.telescope\frequire\0", "config", "telescope.nvim")
time([[Config for telescope.nvim]], false)
vim.cmd [[augroup packer_load_aucmds]]
vim.cmd [[au!]]
  -- Event lazy-loads
time([[Defining lazy-load event autocommands]], true)
vim.cmd [[au BufRead * ++once lua require("packer.load")({'Comment.nvim', 'nvim-spectre', 'goto-preview', 'gitsigns.nvim', 'playground', 'indent-blankline.nvim', 'nvim-lastplace', 'hop.nvim', 'nvim-hlslens', 'vim-sandwich'}, { event = "BufRead *" }, _G.packer_plugins)]]
vim.cmd [[au BufWinEnter * ++once lua require("packer.load")({'which-key.nvim'}, { event = "BufWinEnter *" }, _G.packer_plugins)]]
time([[Defining lazy-load event autocommands]], false)
vim.cmd("augroup END")

_G._packer.inside_compile = false
if _G._packer.needs_bufread == true then
  vim.cmd("doautocmd BufRead")
end
_G._packer.needs_bufread = false

if should_profile then save_profiles() end

end)

if not no_errors then
  error_msg = error_msg:gsub('"', '\\"')
  vim.api.nvim_command('echohl ErrorMsg | echom "Error in packer_compiled: '..error_msg..'" | echom "Please check your config for correctness" | echohl None')
end
