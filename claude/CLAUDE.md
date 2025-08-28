# Global Claude Code Configuration

This file provides global guidance for Claude Code across all projects and repositories.

## MCP Tool Priority (ALWAYS USE FIRST)

### Documentation & Web Search
```
Docs:    mcp__Ref__ref_search_documentation → mcp__Ref__ref_read_url → WebFetch (fallback)
Search:  mcp__exa__web_search_exa → mcp__exa__crawling_exa → WebSearch (fallback)  
Research: mcp__exa__deep_researcher_start → poll with _check → fallback to manual
Browser: mcp__playwright__browser_* for all automation
```

### Enforcement Rules
1. Always try MCP tools first, even if slightly slower
2. Document reason when using fallback tools
3. Check MCP availability before defaulting to legacy

## Task Management Requirements

### Todo List Usage (CRITICAL)
- **ALWAYS** use TodoWrite tool when starting any multi-step task
- Create todos BEFORE starting work, not after
- Mark tasks as in_progress when starting them
- Mark tasks as completed IMMEDIATELY after finishing
- Break complex tasks into smaller, trackable items
- Keep exactly ONE task in_progress at a time
- Update todo status in real-time for user visibility

## Universal Development Principles

### Code Quality Standards
- Follow existing code patterns and conventions
- Prefer editing existing files over creating new ones
- Never create documentation files unless explicitly requested
- Always use absolute file paths in responses
- Minimize file creation - edit existing files when possible

### Workflow Optimization
- **Start with TodoWrite** for any task requiring multiple steps
- Read files before writing to understand context
- Verify tool availability before usage
- Provide clear reasoning for tool selection
- Include relevant file names and code snippets in responses
- Avoid emojis unless explicitly requested
- Track progress visibly through todo list updates

### Error Handling
- Graceful fallbacks when MCP tools unavailable
- Clear error messages with suggested alternatives
- Document reasoning for tool selection decisions
- Prefer continuation over stopping when possible

## Project Detection Patterns

### Common Indicators
```
Git Repository: Use git status for context
Package.json: Node.js/JavaScript project
Cargo.toml: Rust project  
*.csproj: .NET/C# project
Unity Project: Assets/ and ProjectSettings/ directories
Next.js: pages/ or app/ directory with package.json
```

### Configuration Priority
1. Project-specific CLAUDE.md (if exists)
2. This global configuration
3. Tool-specific defaults
4. Claude Code built-in behaviors

## Integration Guidelines

### With Project Configs
- Global rules apply unless overridden
- Project-specific CLAUDE.md takes precedence
- Merge configurations logically
- Maintain consistency across projects

### With Development Tools
- Respect existing linting and formatting rules
- Use project's preferred package managers
- Follow established build and test patterns
- Integrate with existing CI/CD workflows

## Voice Mode Configuration

### Listening Settings
- Always use min_listen_duration=5 for voice conversations
- This provides 5 seconds of silence before recording stops
- Prevents premature cutoffs during natural pauses in speech

## Universal Commands & Patterns

### File Operations
- Always read before write for existing files
- Use absolute paths in all responses
- Prefer incremental changes over rewrites
- Maintain file structure and organization

### Research & Documentation
- Start with MCP tools for all searches
- Verify information from multiple sources
- Provide context-aware recommendations
- Include source attribution when relevant

### Code Generation & Editing
- Match existing code style and patterns
- Test changes in appropriate environments
- Consider backwards compatibility
- Document significant architectural decisions

This configuration ensures consistent, high-quality assistance across all Claude Code sessions.