# Claude Code Agent Knowledge Base

This comprehensive knowledge base provides detailed guidance and best practices for Claude Code agents, based on official documentation and community best practices as of 2025.

## Knowledge Base Structure

### Core Agent Documentation

1. **[Agent Designer Knowledge](./agent-designer-knowledge.md)**
   - Core design principles and patterns
   - YAML frontmatter best practices
   - System prompt architecture
   - Tool configuration strategies
   - Testing and validation approaches

2. **[Workflow Architect Knowledge](./workflow-architect-knowledge.md)**
   - Multi-agent orchestration patterns
   - Swarm intelligence implementation
   - Quality gates and checkpoints
   - Enterprise workflow features
   - Performance optimization techniques

3. **[Performance Analyzer Knowledge](./performance-analyzer-knowledge.md)**
   - Token usage optimization strategies
   - Performance profiling and metrics
   - Cost analysis and budget management
   - Monitoring and alerting configurations
   - Efficiency scoring and benchmarks

4. **[Claude Config Optimizer Knowledge](./claude-config-optimizer-knowledge.md)**
   - CLAUDE.md best practices
   - Workflow configuration patterns
   - Settings and hooks configuration
   - Environment setup optimization
   - Migration and upgrade strategies

5. **[Agent Template Generator Knowledge](./agent-template-generator-knowledge.md)**
   - Template design patterns
   - Domain-specific customization
   - Template library management
   - Dynamic behavior implementation
   - Maintenance and feedback integration

## Quick Reference

### Agent Design Checklist
- [ ] Single, focused responsibility
- [ ] Clear, action-oriented description
- [ ] Minimal necessary tools
- [ ] Structured system prompt
- [ ] Defined constraints
- [ ] Output format specification

### Performance Optimization Tips
- Use parallel tool invocations when possible
- Batch similar operations together
- Cache frequently accessed data
- Minimize context window usage
- Use appropriate temperature settings

### Workflow Patterns
- **Sequential**: For dependent tasks
- **Parallel**: For independent operations
- **Hub-and-Spoke**: For centralized coordination
- **Mesh**: For complex interdependencies

## Best Practices Summary

### Do's
- Keep agents focused and specialized
- Use clear, descriptive naming
- Document expected inputs/outputs
- Test agent interactions thoroughly
- Monitor performance metrics
- Update knowledge base regularly

### Don'ts
- Create overly complex agents
- Give unnecessary tool permissions
- Ignore token usage efficiency
- Skip validation testing
- Forget error handling
- Neglect documentation updates

## Resources

### Official Documentation
- [Claude Code Overview](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Subagents Documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude 4 Best Practices](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)

### Community Resources
- [Awesome Claude Code](https://github.com/hesreallyhim/awesome-claude-code)
- [Claude Code Agents Collection](https://github.com/wshobson/agents)
- [Claude Flow System](https://github.com/ruvnet/claude-flow)

## Version History

- **v1.0.0** (2025-01-28): Initial knowledge base creation
  - Comprehensive documentation for 5 core agents
  - Best practices from official sources
  - Community patterns and workflows

## Contributing

This knowledge base is maintained for optimal agent performance. To suggest improvements:
1. Test proposed changes thoroughly
2. Document new patterns clearly
3. Include practical examples
4. Reference official sources when possible

## License

This knowledge base is provided as reference material for Claude Code agent development and optimization.