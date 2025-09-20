# Claude IDE Integration - MCP Implementation Plan

## Overview
Complete MCP (Model Context Protocol) implementation for Claude IDE integration in Neovim, matching VSCode capabilities.

## Current Status ✅

### Implemented Features
- **WebSocket Server**: Rust-based server with MCP protocol support
- **Authentication**: Lock file with auth tokens
- **Connection Discovery**: Claude auto-discovers via lock files
- **Basic Tools**:
  - ✅ `getDiagnostics` - Language server diagnostics
  - ✅ `buffer_content` - Get buffer contents
  - ✅ `get_selection` - Current selection
  - ✅ `run_command` - Execute Vim commands
- **Notifications**:
  - ✅ `selection_changed` - Real-time selection updates
  - ✅ `at_mentioned` - Explicit context sending
  - ✅ `diagnostics/updated` - Diagnostics changes

## Must-Have IDE Features (Priority Order)

### 🔴 Critical (Required for Basic IDE Experience)

#### 1. `openFile` Tool
**Purpose**: Open files and navigate to specific locations
**VSCode Behavior**: Opens file, optionally selects text range
**Implementation**:
```rust
// MCP Tool Definition
{
  "name": "openFile",
  "inputSchema": {
    "filePath": "string",
    "startLine": "number?",
    "endLine": "number?"
  }
}
```
**Neovim Handler**: `vim.cmd.edit()`, `vim.fn.cursor()`, visual selection

#### 2. `openDiff` Tool
**Purpose**: Show proposed changes for review
**VSCode Behavior**: Opens side-by-side diff view
**Implementation**:
```rust
// MCP Tool Definition
{
  "name": "openDiff",
  "inputSchema": {
    "old_file_path": "string",
    "new_file_contents": "string",
    "tab_name": "string"
  }
}
```
**Neovim Handler**: Create temp file, use `:diffsplit`

#### 3. `getCurrentSelection` Tool
**Purpose**: Get currently selected text with full context
**VSCode Behavior**: Returns selected text, file path, line numbers
**Implementation**:
```rust
{
  "name": "getCurrentSelection",
  "description": "Get current text selection in active editor"
}
```
**Status**: Partially implemented as `get_selection`

### 🟡 Important (Enhanced IDE Experience)

#### 4. `getOpenEditors` Tool
**Purpose**: List all open files/buffers
**VSCode Behavior**: Returns list of open tabs with metadata
**Implementation**:
```rust
{
  "name": "getOpenEditors",
  "description": "Get list of open files in the editor"
}
```
**Neovim Handler**: `vim.api.nvim_list_bufs()`, filter loaded buffers

#### 5. `getWorkspaceFolders` Tool
**Purpose**: Get project root and workspace information
**VSCode Behavior**: Returns workspace folders
**Implementation**:
```rust
{
  "name": "getWorkspaceFolders",
  "description": "Get workspace folders"
}
```
**Neovim Handler**: `vim.fn.getcwd()`, git root detection

#### 6. `saveFile` Tool
**Purpose**: Save modified files
**VSCode Behavior**: Saves file to disk
**Implementation**:
```rust
{
  "name": "saveFile",
  "inputSchema": {
    "filePath": "string"
  }
}
```
**Neovim Handler**: `:write` command

### 🟢 Nice-to-Have (Advanced Features)

#### 7. `searchInWorkspace` Tool
**Purpose**: Search across project files
**VSCode Behavior**: Grep-like search across workspace
**Neovim Handler**: Telescope integration or ripgrep

#### 8. `runTask` Tool
**Purpose**: Execute build/test tasks
**VSCode Behavior**: Runs configured tasks
**Neovim Handler**: Terminal commands, overseer.nvim integration

#### 9. `getGitStatus` Tool
**Purpose**: Git information for current file
**VSCode Behavior**: Returns git status, branch, changes
**Neovim Handler**: Gitsigns integration

#### 10. `closeAllDiffTabs` Tool
**Purpose**: Clean up diff views after review
**VSCode Behavior**: Closes all diff tabs
**Neovim Handler**: Tab management commands

## Implementation TODO List

### Phase 1: Core Navigation (Week 1)
- [ ] Implement `openFile` tool in Rust MCP handler
- [ ] Create Neovim handler for file opening with line ranges
- [ ] Test file navigation from Claude

### Phase 2: Code Review (Week 1-2)
- [ ] Implement `openDiff` tool
- [ ] Create diff view handler in Neovim
- [ ] Add accept/reject diff commands
- [ ] Test diff workflow end-to-end

### Phase 3: Context Tools (Week 2)
- [ ] Enhance `getCurrentSelection` with full metadata
- [ ] Implement `getOpenEditors`
- [ ] Implement `getWorkspaceFolders`
- [ ] Add `saveFile` tool

### Phase 4: Advanced Features (Week 3+)
- [ ] Add search capabilities
- [ ] Integrate with task runners
- [ ] Add Git integration
- [ ] Implement batch operations

## Architecture Notes

### Tool Communication Flow
```
Claude → MCP Request → Rust Server → Neovim (via stdin)
                                   ← Response ←
```

### Current Limitations
1. **Bidirectional Communication**: Rust can't query Neovim directly
   - Solution: Cache data or use request-response pattern

2. **Async Operations**: Some tools need blocking behavior
   - Solution: Implement coroutine-based handlers like claudecode.nvim

3. **State Management**: Need to track open diffs, selections
   - Solution: Add state manager in Rust or Neovim

## Testing Checklist

### For Each Tool
- [ ] Tool appears in `tools/list` response
- [ ] Tool accepts correct parameters
- [ ] Tool returns MCP-compliant response
- [ ] Neovim handler executes correctly
- [ ] Claude can call and use the tool

### Integration Tests
- [ ] Open file from Claude
- [ ] Review and accept code changes
- [ ] Navigate to errors from diagnostics
- [ ] Search and replace across files

## Success Metrics

### Minimum Viable IDE
- ✅ See diagnostics
- [ ] Open files
- [ ] Review diffs
- [ ] Accept/reject changes

### Full Parity with VSCode
- [ ] All 12 standard MCP tools implemented
- [ ] Real-time updates working
- [ ] Smooth workflow for code changes
- [ ] No manual file navigation needed

## References

### Documentation
- [MCP Specification](https://spec.modelcontextprotocol.io)
- [claudecode.nvim PROTOCOL.md](https://github.com/coder/claudecode.nvim/blob/main/PROTOCOL.md)
- [VSCode MCP Tools List](https://github.com/coder/claudecode.nvim/blob/main/PROTOCOL.md#available-mcp-tools)

### Implementation Examples
- claudecode.nvim: Pure Lua implementation
- VSCode extension: TypeScript reference
- Our approach: Rust bridge for portability

## Next Steps

1. **Immediate**: Implement `openFile` - most critical missing piece
2. **This Week**: Add `openDiff` for code review workflow
3. **Next Week**: Complete context tools
4. **Future**: Consider advanced features based on usage

## Notes

- Tools use **camelCase** naming (not snake_case)
- All tools must return `content` array with `type: "text"`
- Claude adapts to available tools - implement progressively
- Focus on tools that enable core workflows first