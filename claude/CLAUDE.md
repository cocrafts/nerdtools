# Global Claude Code Configuration

Universal guidance for Claude Code across all projects and repositories.

## MCP Tool Priority
**Docs**: mcp__Ref__ref_search_documentation → mcp__Ref__ref_read_url → WebFetch
**Search**: mcp__exa__web_search_exa → mcp__exa__crawling_exa → WebSearch  
**Research**: mcp__exa__deep_researcher_start → poll with _check → manual fallback
**Browser**: mcp__playwright__browser_* for all automation
**Rules**: Try MCP first | Document fallback reasons | Check availability | Built-in tools (Task/Read/Write/Edit/Grep) use directly

## Core Built-in Tools
**Read**: File content | **Write**: Create/overwrite | **Edit**: Modify | **Grep**: Search patterns
**Note**: TodoWrite handled automatically by Claude Code - no configuration needed

## Universal Development Standards
**Code Quality**: Follow patterns | Edit > Create | No unsolicited docs | Absolute paths | Avoid emojis
**Workflow**: Read before write | Verify tools | Clear reasoning | Track progress naturally
**Errors**: Graceful fallback | Clear messages | Document decisions | Continue when possible

## Project Detection & Config Priority
**Detection**: git status | package.json→Node | Cargo.toml→Rust | *.csproj→.NET | Unity→Assets/
**Priority**: Project CLAUDE.md → This global → Tool defaults → Built-in behaviors

## Integration Guidelines
**Projects**: Global applies unless overridden | Project CLAUDE.md precedence | Logical merging
**Dev Tools**: Respect linting | Use preferred managers | Follow build patterns | Integrate CI/CD

## Voice Mode
**Settings**: min_listen_duration=5 (prevents cutoffs during pauses)

## File & Code Operations
**Files**: Read before write | Absolute paths | Incremental changes | Maintain structure
**Research**: MCP tools first | Multiple sources | Context-aware | Source attribution
**Code**: Match style | Test changes | Backwards compatibility | Document decisions

## Claude Code Hooks Configuration

### ⚠️ IMPORTANT: Use specialized agents for Claude config (hook-designer, workflow-architect)

### Structure & Location
```
~/.claude/
├── settings.json      # ✅ Hooks configured HERE (not hooks.json!)
└── hooks/
    ├── entries/       # Hook scripts (.sh/.ts)
    └── logs/          # executions.jsonl
```

### Hook Configuration (settings.json)
```json
{
  "hooks": {
    "UserPromptSubmit": [{
      "hooks": [{
        "type": "command",
        "command": "sh ~/.claude/hooks/entries/user-prompt-submit.sh"
      }]
    }]
  }
}
```

### Hook Events & Guidelines
**Events**: UserPromptSubmit | PreToolUse (can block) | PostToolUse | Notification | Stop | SessionStart
**Rules**: JSON stdin → JSON/exit code response | 60s timeout | Validate inputs
**Test**: `echo '{"prompt":"test"}' | sh ~/.claude/hooks/entries/user-prompt-submit.sh`
**Logs**: `tail ~/.claude/hooks/logs/executions.jsonl`

This configuration ensures consistent, high-quality assistance across all Claude Code sessions.