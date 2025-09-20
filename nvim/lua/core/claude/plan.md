# Claude.nvim Enhancement Plan

## Overview
Transform our existing Claude integration into a modular, feature-rich system that combines the best of our WezTerm-based approach with advanced features inspired by claudecode.nvim.

## Core Philosophy
- **Separation of Concerns**: Keep Claude in a separate terminal (not embedded)
- **Modularity**: Each feature in its own module for maintainability
- **Progressive Enhancement**: Start with core features, add advanced ones gradually
- **Zero Breaking Changes**: Preserve all existing functionality

## Architecture

### Directory Structure
```
nvim/lua/core/claude/
├── init.lua          # Main module entry point & API ✅
├── config.lua        # Configuration management ✅
├── utils.lua         # Shared utilities ✅
├── wezterm.lua       # WezTerm pane management & communication ✅
├── session.lua       # Claude session tracking & management ✅
├── ui.lua           # UI helpers (status, prompts, floating windows) ✅
├── selection.lua     # Smart selection tracking & file references (TODO)
├── diagnostics.lua   # LSP diagnostics integration (TODO)
├── diff.lua         # Diff view management (accept/reject changes) (TODO)
├── tools.lua        # MCP-like tool definitions (future WebSocket) (TODO)
└── plan.md          # This file
```

## Implementation Status

### ✅ Completed Features

#### Phase 1: Core Migration ✅
**Goal**: Split existing claude.lua into modules while preserving functionality

- [x] Create directory structure
- [x] Create init.lua with main API
- [x] Create wezterm.lua for WezTerm integration
- [x] Create config.lua for configuration
- [x] Create utils.lua for shared utilities
- [x] Create session.lua for session management
- [x] Create ui.lua for floating window prompts
- [x] Wire everything together in init.lua

#### Advanced Features Implemented
- [x] **Visual Selection with Text Capture**: Full support for v, V, and Ctrl-V modes with actual text extraction
- [x] **Line Range Support**: Automatic line numbers in references (@file:10-20)
- [x] **PID-based Session Tracking**: Robust session tracking using Claude process PIDs instead of WezTerm pane IDs
- [x] **Floating Prompt Windows**: Multi-line input support with customizable UI
- [x] **Smart Pane Detection**: Directory-based matching with fallback to emoji detection
- [x] **Hook Integration**: Full integration with Claude Code hooks (SessionStart, UserPromptSubmit, Stop)
- [x] **DRY Code Refactoring**: Extracted shared visual selection logic into reusable function

### 🚧 In Progress

#### Phase 2: Selection Enhancement
**Goal**: Smart selection tracking with context

- [x] Port visual selection tracking ✅
- [x] Partial line selection support ✅
- [x] Smart file reference building with line numbers ✅
- [x] Create dedicated selection.lua module
- [x] Add debouncing for visual mode
- [ ] Implement file tree integration (neo-tree, oil)

**Features implemented**:
```lua
-- Smart file references (DONE)
@file.lua:10-20         -- Line range ✅
@file.lua:15            -- Single line ✅

-- With selected text (DONE)
Selected text:
```
function example()
  return true
end
```
```

### 📋 TODO Features

#### Phase 3: Diagnostics Integration
**Goal**: Seamless LSP diagnostics with Claude

- [ ] Create diagnostics.lua module
- [ ] Extract diagnostics for current line/range
- [ ] Format diagnostics for Claude
- [ ] Auto-attach to selections
- [ ] Configurable severity levels

#### Phase 4: UI Enhancements (Partially Complete)
**Goal**: Better user feedback and interaction

- [x] Create ui.lua module ✅
- [x] Floating prompt windows ✅
- [x] Multi-line input support ✅
- [ ] Lualine status integration
- [ ] Progress indicators
- [ ] Toast notifications

#### Phase 5: Diff Management
**Goal**: Visual diff review and management

- [ ] Create diff.lua module
- [ ] Open diffs in new tabs
- [ ] Side-by-side comparison
- [ ] Accept/deny commands
- [ ] Auto-close on accept
- [ ] Preserve terminal layout

#### Phase 6: Advanced Features (Partially Complete)
**Goal**: Power user features

- [x] Session persistence across restarts ✅ (PID-based)
- [x] Project-specific session tracking ✅
- [ ] Project-specific configurations
- [ ] Tool system preparation for MCP
- [ ] Command palette integration
- [ ] History tracking

## Current Implementation Details

### Session Management (NEW: PID-based)
```typescript
// Uses Claude process PID for reliable tracking
interface Session {
  sessionId: string;      // Format: "claude-{pid}-{timestamp}"
  dir: string;           // Working directory
  timestamp: string;     // ISO timestamp
  claudePid: number;     // Claude process PID
}
```

### Visual Selection Support (ENHANCED)
```lua
-- Captures actual selected text in all modes:
- Character-wise (v): Partial or full lines
- Line-wise (V): Complete lines
- Block-wise (Ctrl-V): Rectangular blocks

-- Includes text in prompts:
@file.lua:42-55

Selected text:
```
[actual selected code]
```
```

### Configuration System (ACTIVE)
```lua
require("core.claude").setup({
  -- Core
  tracking_file = "~/.claude/active-sessions.txt",  -- ✅
  focus_after_send = true,                          -- ✅

  -- Keymaps (working)
  keymaps = {
    send = "aI",                    -- ✅
    send_with_prompt = "ai",        -- ✅
    focus_claude = "af",            -- ✅
  },
})
```

## Commands (ACTIVE)

### Core Commands ✅
- `:ClaudeSend` - Send current context to Claude
- `:ClaudeFocus` - Focus Claude pane
- `:ClaudePanes` - List all WezTerm panes
- `:ClaudeSessions` - List active sessions
- `:ClaudeTest <pane>` - Test pane communication

### TODO Commands
- `:ClaudeAccept` - Accept current diff
- `:ClaudeDeny` - Deny current diff
- `:ClaudeDiffClose` - Close all diff tabs

## Technical Achievements

### Clean Code Architecture
- **Modular Design**: 7 separate modules with clear responsibilities
- **DRY Principles**: Shared visual selection logic extracted
- **Performance**: Efficient caching in session management
- **Error Handling**: Graceful fallbacks at every level

### Robust Session Tracking
- **PID-based**: More reliable than pane IDs
- **Hooks Integration**: SessionStart, UserPromptSubmit, Stop events
- **Multi-session Support**: Track multiple Claude instances
- **Automatic Cleanup**: Stop event handler for session cleanup

### Enhanced User Experience
- **Visual Selection**: Full support with actual text capture
- **Floating Windows**: Beautiful prompt interface
- **Smart Detection**: Directory-based Claude pane matching
- **Focus Management**: Optional auto-focus after send

## Migration Guide

### For Current Users
```lua
-- Old way (still works):
require("core.claude").setup()

-- New way (with options):
require("core.claude").setup({
  focus_after_send = false,
  tracking_file = "~/.claude/active-sessions.txt",
})
```

### Breaking Changes
- None - all existing functionality preserved ✅

## Implementation Checklist

### ✅ Completed
- [x] Create plan.md
- [x] Create init.lua
- [x] Create wezterm.lua
- [x] Create config.lua
- [x] Create utils.lua
- [x] Create session.lua
- [x] Create ui.lua
- [x] Implement visual selection with text
- [x] Implement PID-based session tracking
- [x] Integrate with Claude Code hooks
- [x] Refactor for DRY code

### 📋 TODO
- [ ] Create selection.lua (dedicated module)
- [ ] Create diagnostics.lua
- [ ] Create diff.lua
- [ ] Create tools.lua
- [ ] Add Lualine integration
- [ ] Write comprehensive documentation
- [ ] Create demo video

## Recent Improvements (2025-01-20)

### Major Refactoring
1. **Visual Selection Enhancement**: Now captures and sends actual selected text, not just line numbers
2. **PID-based Sessions**: Switched from WezTerm pane IDs to Claude PIDs for reliable tracking
3. **Code Cleanup**: Extracted 80+ lines of duplicate code into shared function
4. **Session.lua Optimization**: Reduced from 332 to 230 lines by removing obsolete functions
5. **Hook Simplification**: Simplified to use just `bun` command without full paths

### Bug Fixes
- Fixed wrong pane detection when multiple Claude instances running
- Fixed session file parsing with ISO timestamps containing colons
- Fixed visual selection text not being sent with `aI` command
- Fixed cross-directory session detection

## Notes

### Design Decisions
1. **Why PID-based tracking?** - More reliable than pane IDs, survives window changes
2. **Why separate terminal?** - Better for tmux users, cleaner separation
3. **Why no WebSocket yet?** - Simpler, works today, can add later
4. **Why modular?** - Easier to maintain and extend

### Performance Considerations
- Session data cached for 5 seconds
- Lazy load modules where possible
- Minimize vim.fn.system calls
- Efficient string operations for visual selection

### Security Considerations
- Escape shell commands properly ✅
- Validate pane IDs ✅
- Sanitize file paths ✅
- No eval() usage ✅

## Next Steps

1. **Immediate**: Test current implementation thoroughly
2. **Short-term**: Add LSP diagnostics integration
3. **Medium-term**: Implement diff management
4. **Long-term**: Consider MCP protocol for tools

## References
- [claudecode.nvim](https://github.com/coder/claudecode.nvim)
- [MCP Protocol](https://modelcontextprotocol.io)
- [WezTerm CLI](https://wezfurlong.org/wezterm/cli)
- [Neovim LSP](https://neovim.io/doc/user/lsp.html)
