# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NerdTools is a comprehensive development environment for Metacraft developers, synced across macOS and Linux machines via Syncthing. It includes a complete Neovim IDE setup, an LLM-driven machine setup procedure (`setup/`), and custom keyboard configuration through GeekCaps.


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

### Machine Setup

Setup procedure is in `setup/` as markdown documents executed by an LLM (Claude Code).

```
# In Claude Code, in this repo:
"Read setup/ and walk me through. Skip steps already done."
```

Sections:
- `setup/README.md` — entry point + how to use
- `setup/conventions.md` — canonical paths, philosophy
- `setup/00-prerequisites.md` — manual bootstrap (git, nerdtools, Claude Code)
- `setup/01-essentials.md` through `setup/06-shell.md` — execution order

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

3. **Machine Setup** (`setup/`)
   - LLM-driven: markdown sections describe goals, steps, skip rules, verification
   - Source of truth for canonical paths (mise at `~/.local/bin/mise`, etc.)
   - Self-contained: an LLM agent reads `setup/README.md`, walks the sections, asks before sudo, verifies after

4. **Shell init** (`zsh/entry.sh`)
   - Sourced from `~/.zshrc` on each machine
   - Hardcodes paths for tools we install (mise, etc.)
   - Detects brew prefix at runtime (cross-arch)
   - Sources `~/.config/nerdtools/local.zsh` for per-machine override (outside Syncthing)

5. **Configuration Files** (`conf/`)
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

#### Setup markdowns
- Each section: Goal → Preconditions → Steps → Skip rule → Verify → Notes
- Hardcode paths for tools we install; detect for brew/apt
- Adding a new tool: extend the relevant section, not create a new file unless it's a new concern

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
- **Machine setup**: each `setup/*.md` has a `Verify` block; run it after the section to confirm the goal is met

## Important Notes

- Neovim configuration uses Lazy.nvim for plugin management - changes to plugin specs require `:Lazy sync`
- GeekCaps generates Karabiner-Elements configuration - always test keyboard changes carefully
- `setup/*.md` sections have skip rules and are idempotent - safe to re-run
- `~/nerdtools/` is synced across Mac and Linux via Syncthing — anything edited here propagates. Per-machine overrides go in `~/.config/nerdtools/local.zsh` (outside the synced tree).

## Specialized Agents

This repository includes specialized Claude agents for focused tasks:

1. **neovim-configurator** (`.claude/agents/neovim-configurator.md`)
   - Specialist in Neovim configuration, LSP setup, and plugin management
   - Manages the comprehensive IDE setup with 15+ language support
   - Use when: Adding language support, configuring plugins, optimizing performance

For machine setup, work directly with `setup/*.md` sections — no specialized agent needed.

## Agent Usage Guidelines

Consider using specialized agents for **complex tasks** that benefit from domain expertise:

- **neovim-configurator**: Use when:
  - Adding/configuring new language servers or plugins
  - Debugging complex plugin interactions
  - Optimizing startup performance
  - Refactoring large portions of the config

For machine setup, work directly with `setup/*.md` — the markdown describes intent, you execute and verify.

For **simple tasks** (reading files, small edits, quick searches), work directly without agents for better efficiency.