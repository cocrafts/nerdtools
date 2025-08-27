# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NerdTools is a comprehensive development environment automation framework for Metacraft developers. It provides unified configuration management across macOS and Linux, featuring a complete Neovim IDE setup, automated deployment via Ansible, and custom keyboard configuration through GeekCaps.

**Important**: The `apps/` directory contains legacy applications and should be ignored unless explicitly requested.

## Build and Development Commands

### Nim Projects (GeekCaps - Karabiner Configuration)

```bash
# Build and reload Karabiner configuration
cd geekCaps && nimble configure

# Direct compilation
cd geekCaps && nim c geekCaps.nim && ./geekCaps
```

### Neovim Configuration

```bash
# Format all Lua code
stylua nvim/

# Lint Lua configuration
selene nvim/

# Format specific file
stylua nvim/lua/core/init.lua

# Check for typos
typos nvim/
```

### Environment Deployment

```bash
# Deploy macOS environment
ansible-playbook -i hosts.yml macos.yml

# Deploy Linux environment  
ansible-playbook -i hosts.yml linux.yml

# Test individual playbook
ansible-playbook -i hosts.yml ansible/macos/essentials.yml
```

### JavaScript/TypeScript (if working in apps/)

```bash
# Install dependencies
yarn install

# Run lint (via Turbo)
yarn turbo lint

# Run build (via Turbo)
yarn turbo build
```

## Architecture and Code Patterns

### Core Components

1. **Neovim Configuration** (`nvim/`)
   - Entry point: `nvim/init.lua`
   - Plugin configurations: `nvim/lua/core/*.lua`
   - LSP setups: `nvim/lua/core/lsp/*.lua`
   - Custom utilities: `nvim/lua/utils/*.lua`
   - Code pattern: Modular Lua modules with lazy loading via Lazy.nvim

2. **GeekCaps** (`geekCaps/`)
   - Main entry: `geekCaps.nim`
   - Rule modules: `geekCaps/rules/*.nim`
   - Types: `geekCaps/types.nim`, `geekCaps/keys.nim`
   - Pattern: Modular Nim rules that generate JSON for Karabiner-Elements

3. **Ansible Automation** (`ansible/`, root playbooks)
   - Platform-specific: `macos.yml`, `linux.yml`
   - Shared roles: `ansible/*.yml`
   - Pattern: Hierarchical playbook imports with platform detection

4. **Configuration Files** (`conf/`)
   - Terminal configs: `alacritty/`, `kitty.conf`, `wezterm/wezterm.lua`
   - Shell configs: `nushell/`, `zsh/`
   - Tool configs: `aider.conf.yml`, `lazygit.yml`, `starship.toml`

### Code Conventions

#### Lua (Neovim)
- Use `require()` for module imports
- Follow existing key mapping patterns in `utils/key.lua`
- LSP configurations extend base patterns in `core/lsp/`
- Always use Stylua formatting before commit

#### Nim (GeekCaps)
- Snake_case for variables, PascalCase for types
- Rule modules export a single proc returning rule configuration
- Use `nimble configure` to test changes

#### Ansible
- Tasks use descriptive names
- Platform-specific tasks in respective directories
- Use templates from `ansible/*/templates/` for config files

### Key Dependencies and Tools

- **Language versions**: Managed via Mise (see `.mise.toml`)
- **Nim**: Version 2.0.0+ required for GeekCaps
- **Ruby**: 3.4.2 (specified in .mise.toml)
- **Node.js**: Via Yarn 4.7.0 for any JavaScript work
- **AI Assistant**: Aider configured with o4-mini model

### LSP and Development Tools

The repository includes extensive LSP configurations. When adding new language support:
1. Add LSP config in `nvim/lua/core/lsp/[language].lua`
2. Register in `nvim/lua/core/lsp/init.lua`
3. Add null-ls sources if needed in `nvim/lua/core/lsp/none-ls.lua`

### Testing and Validation

- **Lua**: Run `selene nvim/` before committing Neovim configs
- **Nim**: Test GeekCaps with `nimble configure` after changes
- **Typos**: Run `typos` in project root to catch spelling errors
- **Ansible**: Use `--check` flag to dry-run playbooks

## Important Notes

- Neovim configuration uses Lazy.nvim for plugin management - changes to plugin specs require `:Lazy sync`
- GeekCaps generates Karabiner-Elements configuration - always test keyboard changes carefully
- Ansible playbooks are idempotent - safe to run multiple times
- The repository uses Yarn workspaces but apps/ directory is legacy

## Specialized Agents

This repository includes specialized Claude agents for focused tasks:

1. **ansible-deployer** (`.claude/agents/ansible-deployer.md`)
   - Expert in Ansible playbook management and environment deployment
   - Handles macOS/Linux system configuration and tool installation
   - Use when: Setting up new machines, adding software, troubleshooting deployments

2. **neovim-configurator** (`.claude/agents/neovim-configurator.md`)
   - Specialist in Neovim configuration, LSP setup, and plugin management
   - Manages the comprehensive IDE setup with 15+ language support
   - Use when: Adding language support, configuring plugins, optimizing performance

## Agent Usage Guidelines

Consider using specialized agents for **complex tasks** that benefit from domain expertise:

- **neovim-configurator**: Use when:
  - Adding/configuring new language servers or plugins
  - Debugging complex plugin interactions
  - Optimizing startup performance
  - Refactoring large portions of the config
  
- **ansible-deployer**: Use when:
  - Setting up new machines from scratch
  - Adding multiple software packages
  - Creating new playbook roles
  - Troubleshooting deployment failures

For **simple tasks** (reading files, small edits, quick searches), work directly without agents for better efficiency.