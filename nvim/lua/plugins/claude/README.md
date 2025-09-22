# Claude IDE Integration for Neovim

Pure Lua implementation of the Claude Code IDE integration using the MCP (Model Context Protocol).

## Features

- ✅ **WebSocket Server** - Full RFC 6455 compliant WebSocket implementation
- ✅ **MCP Protocol** - Complete JSON-RPC 2.0 based Model Context Protocol
- ✅ **Auto-discovery** - Lock file mechanism for Claude Code to find Neovim
- ✅ **File Operations** - Open, navigate, and manage files from Claude
- ✅ **Diagnostics** - Share LSP diagnostics with Claude
- ✅ **Selection Tracking** - Real-time selection synchronization
- ✅ **Buffer Management** - Track open buffers and content changes
- ✅ **Multiple Tools** - openFile, getDiagnostics, getOpenEditors, etc.

## Installation

This plugin is already integrated in your Neovim configuration at `nvim/lua/plugins/claude/`.

## Usage

### Starting the Server

The server starts automatically when Neovim loads. You can also control it manually:

```vim
:ClaudeStart    " Start the Claude IDE server
:ClaudeStop     " Stop the server
:ClaudeRestart  " Restart the server
:ClaudeStatus   " Check connection status
```

### Connecting Claude Code

1. Start Neovim (server auto-starts)
2. Check the port with `:ClaudeStatus`
3. Start Claude Code - it will auto-detect and connect

### Sending Context to Claude

In visual mode:
```vim
:ClaudeSend     " Send selected text to Claude
```

## Available MCP Tools

Claude can use these tools to interact with Neovim:

| Tool | Description |
|------|-------------|
| `openFile` | Open files with optional line/text selection |
| `getCurrentSelection` | Get the current text selection |
| `getOpenEditors` | List all open buffers |
| `getWorkspaceFolders` | Get workspace information |
| `getDiagnostics` | Get LSP diagnostics for files |

## Architecture

```
Claude Code <--[WebSocket]--> Neovim Server
                |
                v
         MCP Protocol (JSON-RPC)
                |
                v
         Tool Execution & Events
```

### Components

- **server.lua** - WebSocket server with TCP transport
- **protocol.lua** - MCP protocol handler
- **tools.lua** - Tool implementations (openFile, etc.)
- **handshake.lua** - WebSocket handshake (RFC 6455)
- **frame.lua** - WebSocket frame encoding/decoding
- **lockfile.lua** - Lock file management for discovery
- **selection.lua** - Selection tracking
- **buffer.lua** - Buffer content management
- **utils.lua** - SHA1, Base64, and bit operations

## Configuration

Set log level in your plugin config:

```lua
require("plugins.claude").setup({
    log_level = vim.log.levels.INFO,  -- or DEBUG for troubleshooting
    port_min = 10000,
    port_max = 65535,
})
```

## Lock File

The lock file is created at `~/.claude/ide/[port].lock`:

```json
{
  "pid": 12345,
  "workspaceFolders": ["/path/to/project"],
  "ideName": "Neovim",
  "transport": "ws",
  "authToken": "uuid-token"
}
```

## Troubleshooting

### Claude shows "IDE disconnected"

1. Check if server is running: `:ClaudeStatus`
2. Restart the server: `:ClaudeRestart`
3. Check for errors: `:messages`

### Connection issues

1. Enable debug logging:
   ```lua
   require("plugins.claude").setup({
       log_level = vim.log.levels.DEBUG
   })
   ```

2. Check lock file exists:
   ```bash
   ls ~/.claude/ide/*.lock
   ```

3. Test WebSocket manually:
   ```bash
   python3 test_websocket.py
   ```

## Protocol Details

### WebSocket Handshake
- Uses pure Lua SHA1 implementation
- No authentication required for localhost connections
- Compliant with RFC 6455

### MCP Messages

Initialize request from Claude:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05"
  }
}
```

Tool call example:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "openFile",
    "arguments": {
      "filePath": "/path/to/file.lua",
      "startLine": 10,
      "endLine": 20
    }
  }
}
```

## Credits

Based on [claudecode.nvim](https://github.com/coder/claudecode.nvim) architecture with improvements for the nerdtools environment.