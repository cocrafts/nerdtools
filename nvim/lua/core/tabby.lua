-- Tabby AI Code Completion Configuration
-- Server: RTX 5090 with Qwen3-Coder:30b

local M = {}

M.configure = function()
  -- First, configure the server URL for the agent
  vim.g.tabby_server_url = "http://192.168.1.5:8080"

  -- Configure the agent command to connect to our server
  -- Use full path to node and tabby-agent for mise compatibility
  -- Load token from environment variable TABBY_AUTH_TOKEN
  local auth_token = vim.env.TABBY_AUTH_TOKEN or ""

  vim.g.tabby_agent_start_command = {
    "/Users/le/.local/share/mise/installs/node/24.1.0/bin/node",
    "/Users/le/.local/share/mise/installs/node/24.1.0/lib/node_modules/tabby-agent/dist/node/index.js",
    "--server",
    "http://192.168.1.5:8080",
    "--token",
    auth_token,
    "--stdio",
  }

  -- Configure inline completion settings (as per documentation)
  -- Using Shift+Enter to accept to avoid conflict with existing Tab mappings (cmp/snippets)
  vim.g.tabby_inline_completion_trigger = "auto"                        -- auto trigger completions
  vim.g.tabby_inline_completion_keybinding_accept = "<S-CR>"            -- Shift+Enter to accept AI suggestions
  vim.g.tabby_inline_completion_keybinding_trigger_or_dismiss = "<C-\\>" -- Ctrl-\ to trigger/dismiss

  -- Setup Tabby using the correct module path
  local ok, tabby = pcall(require, "tabby")
  if ok then
    -- Tabby plugin is loaded
    vim.notify("Tabby plugin loaded successfully", vim.log.levels.INFO)
  else
    -- Try vim configuration
    vim.cmd([[
      " Ensure Tabby is initialized
      if exists('*tabby#Setup')
        call tabby#Setup()
      endif
    ]])
  end

  -- Print keybinding info on startup
  vim.defer_fn(function()
    print("🤖 Tabby AI: Shift+Enter to accept, Ctrl+\\ to trigger/dismiss")
  end, 1000)

  -- Visual feedback
  vim.api.nvim_set_hl(0, "TabbyCompletion", { fg = "#808080", italic = true })

  -- Status line component (optional)
  vim.g.tabby_status = function()
    if vim.fn["tabby#IsAvailable"]() then
      return "🤖 Tabby"
    end
    return ""
  end

  -- Auto-commands for better integration
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python", "javascript", "typescript", "lua", "rust", "go", "java", "cpp", "c" },
    callback = function()
      -- Enable Tabby for coding files
      vim.b.tabby_enabled = true
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text", "gitcommit" },
    callback = function()
      -- Disable Tabby for non-code files
      vim.b.tabby_enabled = false
    end,
  })

  -- Check if token is configured
  local auth_token = vim.env.TABBY_AUTH_TOKEN
  if not auth_token or auth_token == "" then
    print("⚠️  Tabby AI: Set TABBY_AUTH_TOKEN environment variable to enable")
  else
    print("✅ Tabby AI configured - Server: http://192.168.1.5:8080")
  end
end

return M
