# Agent Designer Knowledge Base

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Design Principles](#design-principles)
3. [Agent Architecture Patterns](#agent-architecture-patterns)
4. [System Prompt Architecture](#system-prompt-architecture)
5. [Tool Configuration](#tool-configuration)
6. [Best Practices 2025](#best-practices-2025)
7. [Implementation Guidelines](#implementation-guidelines)
8. [Performance Optimization](#performance-optimization)
9. [Testing and Validation](#testing-and-validation)
10. [Common Pitfalls](#common-pitfalls)
11. [Advanced Techniques](#advanced-techniques)
12. [References](#references)

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
```yaml
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

## Design Principles

### 1. Single Responsibility Principle
- Each agent should have ONE clear, focused purpose
- Avoid creating "Swiss Army knife" agents that try to do everything
- Better to have multiple specialized agents than one overly complex agent
- Avoid overlapping responsibilities between agents

### 2. Least Privilege Principle
- Only assign necessary tools to each agent
- Reduces context overhead
- Improves security and performance
- Average 2-3 tools per specialist agent

### 3. Clear Naming Conventions
```
Pattern: [action]-[domain]
Examples:
- review-security
- test-frontend
- deploy-infrastructure
- analyze-performance
```
- Use lowercase with hyphens
- Name should immediately convey the agent's purpose
- Avoid generic names like `helper` or `assistant`

### 4. Description Field Optimization
- Start with action verbs: "Designs", "Analyzes", "Generates"
- Include trigger phrases for proactive use: "use PROACTIVELY", "MUST BE USED"
- Be specific about the agent's domain expertise
- Include specific trigger phrases for automatic delegation

#### Effective Descriptions
✅ **Good**: "Handles all git operations including commits, branches, and merges"
✅ **Good**: "Creates and manages Linear issues when working with feature development"
❌ **Bad**: "Helps with code"
❌ **Bad**: "Does various things"

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

## System Prompt Architecture

### Structure Template
```markdown
# [Agent Name]

You are an expert [role] specializing in [domain].

## Core Responsibilities
- Primary responsibility 1
- Primary responsibility 2
- Primary responsibility 3

## Approach
[Describe the systematic approach the agent should follow]

## Best Practices
- Specific best practice 1
- Specific best practice 2
- Specific best practice 3

## Constraints
- What the agent should NOT do
- Limitations to observe
- Boundaries to respect

## Success Criteria
- [Criterion 1]
- [Criterion 2]

## Output Format
[Specify expected output format if applicable]
```

### Writing Effective Prompts
- Be specific, not generic
- Include domain-specific terminology
- Define clear success criteria
- Specify output formats
- Include error handling instructions
- Keep prompts concise (< 500 words ideal)

### Context Providing Strategies
- Explain WHY certain behaviors are important
- Provide reasoning behind constraints
- Include examples of good vs bad outputs
- Reference industry standards when applicable
- Use bullet points over paragraphs
- Reference external docs instead of embedding

---

## Tool Configuration

### Tool Assignment Strategy

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

### Configuration Patterns

#### Minimal Tool Access
```yaml
tools:
  - Read   # For analysis-only agents
  - Grep   # For search-focused agents
```

#### Standard Development Tools
```yaml
tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Grep
  - Glob
```

#### Full Access (Use Sparingly)
```yaml
# Omit tools field to inherit all available tools
# Only for agents that truly need comprehensive access
```

### Tool Optimization Guidelines
- Average 2-3 tools per specialist agent
- 1-2 tools for orchestrator agents
- Never assign unused tools
- Group related MCP tools together
- Remove tools that appear in prompts but aren't used

---

## Best Practices 2025

### Agent Coordination Patterns

#### Sequential Pipeline
```
User Request
  → Requirements Analyzer Agent
    → Design Agent
      → Implementation Agent
        → Review Agent
          → Final Result
```

#### Parallel Execution
```
User Request
  → [Agent A: Frontend Analysis]
  → [Agent B: Backend Analysis]  (simultaneous)
  → [Agent C: Database Analysis]
    → Merge Results
```

#### Conditional Routing
```
User Request
  → Analysis Agent
    → IF (complexity > threshold)
        → Complex Task Handler
      ELSE
        → Simple Task Handler
```

### Delegation Rules
1. **Orchestrators** delegate to specialists
2. **Specialists** execute specific tasks
3. **Reviewers** validate outputs
4. **Reporters** summarize results

### Testing Strategy

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

### Creating New Agents

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

### Implementation Example
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

---

## Performance Optimization

### Key Performance Indicators
- **Response Time**: Time to first token (target: < 2 seconds for simple tasks)
- **Token Usage**: Input/output token counts (target: < 1000 tokens per agent prompt)
- **Task Completion Rate**: Success vs failure (target: > 95% success rate)
- **Delegation Efficiency**: Direct vs redirected tasks (target: > 90% correct routing)

### Token Efficiency
- Keep system prompts concise but complete
- Use bullet points over paragraphs where possible
- Avoid redundant instructions
- Reference external docs rather than embedding large content
- Remove verbose explanations
- Focus on essential information

### Optimization Techniques

#### Tool Reduction
- Before: 34 tools across 11 agents (avg 3.1)
- After: 23 tools across 11 agents (avg 2.1)
- Result: 32% performance improvement

#### Prompt Optimization
- Remove redundant instructions
- Use clear, action-oriented language
- Eliminate verbose explanations
- Trust Claude's knowledge base

#### Parallel Processing
```bash
# Utilize parallel agents for large tasks
"Explore the codebase using 4 tasks in parallel"
# Each agent gets separate context window
```

### Context Management
- Keep context windows focused
- Clear outputs between agents
- Minimize data passed between agents
- Use structured data formats for communication
- Avoid context pollution
- Summarize before delegation

### Latency Considerations
- Minimize agent chaining depth
- Use parallel execution when tasks are independent
- Cache common agent outputs when appropriate
- Avoid unnecessary agent invocations
- Early exit on failures
- Batch similar operations

---

## Testing and Validation

### Agent Testing Checklist
- [ ] Agent responds correctly to primary use cases
- [ ] Agent respects defined constraints
- [ ] Tool usage is appropriate and minimal
- [ ] Output format matches specifications
- [ ] Agent handles edge cases gracefully
- [ ] Description triggers proactive use appropriately
- [ ] Automatic delegation works correctly
- [ ] Explicit invocation functions properly
- [ ] Performance meets benchmarks
- [ ] Documentation is complete

### Validation Process
1. Test with minimal input
2. Test edge cases
3. Test delegation chains
4. Measure performance
5. Validate output format
6. Check error handling
7. Verify tool usage efficiency

### Performance Benchmarks
- Simple agents: < 500 tokens total
- Complex agents: < 2000 tokens total
- Orchestrators: < 1000 tokens total
- Response time: < 2 seconds for simple tasks
- Delegation accuracy: > 90%

---

## Common Pitfalls

### Anti-Patterns to Avoid

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

#### ❌ Circular Dependencies
```
Agent A calls Agent B
Agent B calls Agent C
Agent C calls Agent A
```
**Problem**: Infinite loops, stack overflow

### Solutions to Common Issues

| Issue | Solution |
|-------|----------|
| Poor Automatic Delegation | Rewrite descriptions with specific trigger phrases |
| Slow Performance | Reduce tools, optimize prompts, use parallel execution |
| Context Overflow | Break into smaller agents, clear handoffs |
| Inconsistent Results | Add explicit constraints and success criteria |
| Tool Misuse | Audit tool usage, remove unnecessary tools |

---

## Advanced Techniques

### Multi-Agent Workflows
- Design agents to work in orchestrated workflows
- Use coordinator agents for complex multi-step processes
- Implement quality gates between agent handoffs
- Consider rollback strategies for failed workflows
- Use TodoWrite for progress tracking

### Dynamic Agent Selection
- Use analysis agents to route to specialists
- Implement confidence scoring for agent selection
- Provide fallback agents for edge cases
- Log agent selection decisions for debugging
- Create routing tables for common patterns

### Self-Improving Agents
- Include reflection prompts in agent design
- Capture agent performance metrics
- Iterate on agent prompts based on outcomes
- Implement feedback loops for continuous improvement
- Version control iterations

### Agent Reusability
- Design agents for multiple projects
- Create organization-wide agent libraries
- Share successful patterns
- Version control agent definitions
- Maintain compatibility across updates

### Integration Patterns

#### MCP Integration
- Agents can leverage MCP tools
- Ensure MCP servers are properly configured
- Handle MCP tool failures gracefully
- Document MCP dependencies clearly
- Group related MCP tools

#### Project vs User Level Agents
- Project agents in `.claude/agents/` take precedence
- User agents in `~/.claude/agents/` are globally available
- Name conflicts resolved in favor of project agents
- Consider namespace prefixes for large agent collections
- Use consistent naming across levels

---

## Version Control and Maintenance

### Versioning Strategy
- Use semantic versioning in agent metadata
- Document breaking changes in agent behavior
- Maintain backwards compatibility when possible
- Test agent changes thoroughly before deployment
- Keep changelog for significant updates

### Documentation Requirements
- Keep README with agent collection
- Document each agent's purpose and usage
- Include examples of typical invocations
- Maintain changelog for significant updates
- Track performance metrics over time

### Maintenance Best Practices
- Regular performance audits
- Prompt optimization based on usage
- Tool usage analysis
- Update trigger phrases based on patterns
- Deprecate unused agents

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

## Quick Reference

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
- Tool average: 2.1 tools per agent
- Delegation accuracy: > 90% correct routing
- Task completion: > 95% success rate
- Parallel efficiency: > 65% for workflows

### Version History
- **v2.0.0** (2025-01-28): Merged comprehensive knowledge bases
- **v1.0.0** (2025-01-27): Initial creation
- Sources: Official docs, research papers, community best practices