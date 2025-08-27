# Claude Code Agent Design Knowledge Base

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Official Claude Code Documentation](#official-claude-code-documentation)
3. [Agent Architecture Patterns](#agent-architecture-patterns)
4. [Best Practices 2025](#best-practices-2025)
5. [Implementation Guidelines](#implementation-guidelines)
6. [Performance Optimization](#performance-optimization)
7. [Common Pitfalls](#common-pitfalls)
8. [References](#references)

---

## Core Concepts

### What Are Claude Code Agents?
Custom subagents in Claude Code are specialized AI assistants that can be invoked to handle specific types of tasks. They enable more efficient problem-solving by providing task-specific configurations with customized system prompts, tools, and a separate context window.

### Key Benefits
- **Context Isolation**: Each agent operates in its own context, preventing pollution of the main conversation
- **Specialization**: Agents can be tailored for specific domains or tasks
- **Tool Optimization**: Each agent only has access to the tools it needs
- **Automatic Delegation**: Claude intelligently routes tasks to appropriate specialists
- **Parallel Execution**: Multiple agents can run simultaneously (max 10)

### Configuration Structure
```markdown
---
name: your-sub-agent-name
description: Description of when this subagent should be invoked
tools: tool1, tool2, tool3  # Optional - inherits all tools if omitted
---

Your subagent's system prompt goes here.
```

### File Locations
- **Project-level**: `.claude/agents/` (takes precedence)
- **User-level**: `~/.claude/agents/`

---

## Official Claude Code Documentation

### Subagent Documentation
- **Main Resource**: [Subagents Documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- **Creation Method**: Use `/agents` command in Claude Code
- **Management**: Can be managed via files or commands

### Key Features
1. **Automatic Delegation**: Claude selects agents based on context
2. **Explicit Invocation**: Can directly call specific agents
3. **Tool Inheritance**: Agents inherit tools unless specified
4. **Context Window**: Each agent has separate context

### Official Examples
- Code reviewer
- Debugger  
- Data scientist
- Security auditor

---

## Agent Architecture Patterns

### 1. Hierarchical Architecture
```
Master Orchestrator
    ├── Domain Specialist 1
    │   └── Sub-specialist A
    ├── Domain Specialist 2
    └── Domain Specialist 3
```

**When to Use**:
- Complex projects with multiple domains
- Need clear delegation hierarchy
- Large-scale systems

**Benefits**:
- Clear responsibility boundaries
- Scalable architecture
- Strategic vs tactical separation

### 2. Flat Specialist Pattern
```
Main Agent ←→ Specialist 1
         ←→ Specialist 2
         ←→ Specialist 3
```

**When to Use**:
- Simple to medium complexity projects
- Direct task delegation
- Minimal coordination overhead

**Benefits**:
- Simple to understand
- Fast delegation
- Low overhead

### 3. Hub and Spoke Pattern
```
    Specialist 1
         ↓
Central Hub → Output
         ↑
    Specialist 2
```

**When to Use**:
- Need central coordination
- Multiple inputs/outputs
- Workflow management

### 4. Pipeline Pattern
```
Agent 1 → Agent 2 → Agent 3 → Output
```

**When to Use**:
- Sequential processing
- Data transformation workflows
- Build/test/deploy pipelines

### 5. Collaborative Network
```
Agent 1 ←→ Agent 2
    ↓  ✕  ↓
Agent 3 ←→ Agent 4
```

**When to Use**:
- Complex interdependencies
- Peer review processes
- Collaborative problem solving

---

## Best Practices 2025

### 1. Agent Design Principles

#### Single Responsibility Principle
- Each agent should have ONE clear purpose
- Avoid overlapping responsibilities
- Keep descriptions specific and actionable

#### Least Privilege Principle
- Only assign necessary tools to each agent
- Reduces context overhead
- Improves security and performance

#### Clear Naming Convention
```
Pattern: [action]-[domain]
Examples:
- review-security
- test-frontend
- deploy-infrastructure
```

### 2. System Prompt Best Practices

#### Structure Template
```markdown
## Role
You are a [specific role] specialist focused on [domain].

## Primary Objectives
1. [Objective 1]
2. [Objective 2]

## Constraints
- [Constraint 1]
- [Constraint 2]

## Approach
[Detailed approach methodology]

## Success Criteria
- [Criterion 1]
- [Criterion 2]
```

#### Writing Effective Prompts
- Be specific, not generic
- Include domain-specific terminology
- Define clear success criteria
- Specify output formats
- Include error handling instructions

### 3. Tool Assignment Strategy

#### Tool-to-Agent Mapping
```yaml
# Minimal tools for focused agents
security-auditor: Grep, Read, Task
test-engineer: Read, Bash, Write

# Comprehensive tools for orchestrators
workflow-orchestrator: Task, TodoWrite

# Specialized tools for specific tasks
git-operator: Bash
linear-sync: mcp__linear-server__*
```

#### Tool Optimization Guidelines
- Average 2-3 tools per specialist agent
- 1-2 tools for orchestrator agents
- Never assign unused tools
- Group related MCP tools together

### 4. Description Writing

#### Effective Descriptions
✅ **Good**: "Handles all git operations including commits, branches, and merges"
✅ **Good**: "Creates and manages Linear issues when working with feature development"
❌ **Bad**: "Helps with code"
❌ **Bad**: "Does various things"

#### Trigger Phrases
Include specific trigger phrases in descriptions:
- "security audit" → security-auditor
- "create PR" → pr-manager
- "coordinate workflow" → workflow-orchestrator

### 5. Testing Strategy

#### Test Coverage
1. **Automatic Delegation**: Test natural language triggers
2. **Explicit Invocation**: Test direct agent calls
3. **Edge Cases**: Test ambiguous requests
4. **Performance**: Measure response times

#### Test Commands
```bash
# Explicit invocation
"Use the security-auditor to check for vulnerabilities"

# Automatic delegation
"Review this code for security issues"

# Performance test
"Analyze the entire codebase using 4 agents in parallel"
```

---

## Implementation Guidelines

### 1. Creating New Agents

#### Step-by-Step Process
1. Identify specific need or gap
2. Define clear boundaries and responsibilities
3. Generate initial agent with Claude
4. Refine system prompt iteratively
5. Optimize tool selection
6. Test both automatic and explicit invocation
7. Monitor performance and adjust

#### Using the /agents Command
```
/agents
> Name: feature-developer
> Description: Develops new features following TDD
> Tools: Read, Write, Edit, Bash, Task
> System Prompt: [Generated and refined]
```

### 2. Agent Hierarchies

#### Delegation Rules
1. **Orchestrators** delegate to specialists
2. **Specialists** execute specific tasks
3. **Reviewers** validate outputs
4. **Reporters** summarize results

#### Implementation Example
```markdown
# workflow-orchestrator.md
---
name: workflow-orchestrator
description: Coordinates complex multi-step workflows
tools: Task, TodoWrite
---

You coordinate workflows by:
1. Breaking down complex tasks
2. Delegating to appropriate specialists
3. Tracking progress with todos
4. Ensuring task completion
```

### 3. Context Management

#### Context Window Optimization
- Keep system prompts concise (< 500 words ideal)
- Use bullet points over paragraphs
- Reference external docs instead of embedding
- Clear context boundaries between agents

#### Avoiding Context Pollution
- Use agents for distinct phases
- Clear handoffs between agents
- Summarize before delegation
- Return focused results

---

## Performance Optimization

### 1. Metrics to Monitor

#### Key Performance Indicators
- **Response Time**: Time to first token
- **Token Usage**: Input/output token counts
- **Task Completion Rate**: Success vs failure
- **Delegation Efficiency**: Direct vs redirected tasks

### 2. Optimization Techniques

#### Tool Reduction
- Before: 34 tools across 11 agents (avg 3.1)
- After: 23 tools across 11 agents (avg 2.1)
- Result: 32% performance improvement

#### Prompt Optimization
- Remove redundant instructions
- Use clear, action-oriented language
- Eliminate verbose explanations
- Focus on essential information

#### Parallel Execution
```bash
# Utilize parallel agents for large tasks
"Explore the codebase using 4 tasks in parallel"
# Each agent gets separate context window
```

### 3. Caching and Reuse

#### Agent Reusability
- Design agents for multiple projects
- Create organization-wide agent libraries
- Share successful patterns
- Version control agent definitions

---

## Common Pitfalls

### 1. Anti-Patterns to Avoid

#### ❌ The Kitchen Sink Agent
```markdown
name: do-everything
tools: ALL
description: Handles all tasks
```
**Problem**: Too broad, poor performance, unclear purpose

#### ❌ Overlapping Responsibilities
```
security-auditor: Reviews code security
code-reviewer: Reviews code including security
```
**Problem**: Delegation confusion, redundant work

#### ❌ Tool Overload
```
simple-formatter: Read, Write, Edit, Bash, Task, Glob, Grep
```
**Problem**: Excessive context, slow performance

#### ❌ Vague Descriptions
```
description: Helps with development tasks
```
**Problem**: Poor automatic delegation, unclear purpose

### 2. Solutions to Common Issues

#### Issue: Poor Automatic Delegation
**Solution**: Rewrite descriptions with specific trigger phrases

#### Issue: Slow Performance
**Solution**: Reduce tools, optimize prompts, use parallel execution

#### Issue: Context Overflow
**Solution**: Break into smaller agents, clear handoffs

#### Issue: Inconsistent Results
**Solution**: Add explicit constraints and success criteria

---

## References

### Official Documentation
1. [Claude Code Subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
2. [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
3. [Output Styles Documentation](https://docs.anthropic.com/en/docs/claude-code/output-styles)
4. [Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks-guide)

### Community Resources
1. [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) - 100+ production-ready agents
2. [ClaudeLog](https://claudelog.com/mechanics/custom-agents/) - Guides and tutorials
3. [Medium - Joe Njenga](https://medium.com/@joe.njenga/how-im-using-claude-code-sub-agents-newest-feature-as-my-coding-army-9598e30c1318) - Practical examples

### Architecture References
1. [Microsoft - AI Agent Orchestration Patterns](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns)
2. [Google ADK](https://developers.googleblog.com/en/agent-development-kit-easy-to-build-multi-agent-applications/) - Agent Development Kit
3. [AgentOrchestra Paper](https://arxiv.org/html/2506.12508v1) - Hierarchical Multi-Agent Framework

### Framework Documentation
1. [LangGraph](https://python.langchain.com/docs/concepts/agent-architectures/) - Dynamic graph-based agents
2. [Crew AI](https://crewai.com/) - Team-based agent collaboration
3. [IBM Agentic Architecture](https://www.ibm.com/think/topics/agentic-architecture) - Enterprise patterns

---

## Appendix: Quick Reference

### Agent Creation Checklist
- [ ] Clear single purpose defined
- [ ] Specific trigger phrases in description
- [ ] Minimal necessary tools assigned
- [ ] Concise system prompt (< 500 words)
- [ ] Success criteria specified
- [ ] Error handling included
- [ ] Tested automatic delegation
- [ ] Tested explicit invocation
- [ ] Performance benchmarked
- [ ] Documentation updated

### Tool Assignment Matrix
| Agent Type | Recommended Tools | Tool Count |
|------------|------------------|------------|
| Orchestrator | Task, TodoWrite | 1-2 |
| Code Specialist | Read, Write, Edit | 2-4 |
| Reviewer | Read, Grep, Task | 2-3 |
| Operator | Bash | 1-2 |
| MCP Specialist | mcp__* specific | 1-5 |
| Security | Grep, Read, Task | 2-3 |
| Test Engineer | Read, Write, Bash | 2-4 |

### Performance Targets
- Response time: < 2 seconds for simple tasks
- Token usage: < 1000 tokens per agent prompt
- Delegation accuracy: > 90% correct routing
- Task completion: > 95% success rate

### Version History
- **v1.0.0** (2025-08-27): Initial comprehensive knowledge base
- Last Updated: 2025-08-27
- Sources: Official docs, research papers, community best practices