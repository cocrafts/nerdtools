-- vim-herdr-navigation — Neovim side
--
-- Seamless <C-h/j/k/l> navigation between Neovim splits and herdr panes: move
-- between Neovim splits, and at a split edge hand off to herdr so focus crosses
-- into the neighbouring herdr pane. When not inside herdr it falls back to tmux
-- (if any) or plain wincmd, so a tmux setup keeps working.
--
-- Load it so it wins over other <C-h/j/k/l> mappings (e.g. vim-tmux-navigator).
-- The simplest reliable way is to drop it in your config's after/plugin dir:
--   cp editor/nvim.lua ~/.config/nvim/after/plugin/herdr_nav.lua
-- or source it from your config after plugins load:
--   dofile("/path/to/vim-herdr-navigation/editor/nvim.lua")

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the surrounding multiplexer.
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == "" then
      herdr = "herdr"
    end
    vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
  elseif vim.env.HC_TERMINAL_ID and vim.env.HC_TERMINAL_ID ~= "" then
    vim.fn.jobstart({ "hc", "label", vim.env.HC_TERMINAL_ID, ("herdr.nav=%s:%d"):format(dir, vim.uv.hrtime()) })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux[dir])
  end
end

local mods = vim.g.herdr_nav_mods or { "C" }

local function map(key, dir, desc)
  for _, mod in ipairs(mods) do
    vim.keymap.set("n", "<" .. mod .. "-" .. key .. ">", function()
      nav(key, dir)
    end, { silent = true, noremap = true, desc = desc })
  end
end

map("h", "left", "Navigate left (vim/herdr)")
map("j", "down", "Navigate down (vim/herdr)")
map("k", "up", "Navigate up (vim/herdr)")
map("l", "right", "Navigate right (vim/herdr)")

-- Tell the herdr side that Neovim owns this pane's <C-h/j/k/l>. herdr detects
-- Vim from the pane's foreground process, which needs a tty process group and
-- so never works on Windows/ConPTY. A marker file works everywhere.
local function marker()
  local pane = vim.env.HERDR_PANE_ID
  if pane == nil or pane == "" then
    return nil
  end
  local sock = vim.env.HERDR_SOCKET_PATH
  local dir
  if sock ~= nil and sock ~= "" then
    dir = vim.fs.dirname(vim.fs.normalize(sock))
  else
    dir = vim.fn.expand("~/.config/herdr")
  end
  return vim.fs.joinpath(dir, "nav", "vim-" .. pane:gsub(":", "-"))
end

local path = marker()
if path then
  local function claim()
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    local file = io.open(path, "w")
    if file then
      file:close()
    end
  end
  claim()
  -- Nested Neovim instances share the pane, so re-claim whenever we regain it.
  vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, { callback = claim })
  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      os.remove(path)
    end,
  })
end
