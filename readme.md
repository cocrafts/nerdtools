# NerdTools

Personal development environment, synced across macOS and Linux machines via Syncthing.

## What's in here

| Path | What |
| ---- | ---- |
| [`zsh/entry.sh`](zsh/entry.sh) | Canonical shell contract — sourced from `~/.zshrc` on every machine |
| [`setup/`](setup/) | LLM-driven machine setup procedure (recipes that satisfy the contract) |
| [`nvim/`](nvim/) | Neovim configuration (Lazy.nvim, 15+ language LSPs) |
| [`geekCaps/`](geekCaps/) | Karabiner-Elements config built from Nim |
| [`conf/`](conf/) | Terminal + tool configs (alacritty, wezterm, kitty, ghostty, tmux, nushell, lazygit, starship, aider) |
| [`claude/`](claude/) | Claude Code config — agents, commands, hooks, rules, skills |
| [`bin/`](bin/) | Personal utility scripts |

## Setting up a new machine

```bash
# 1. Manual bootstrap
sudo apt-get install -y git curl    # Linux
xcode-select --install              # macOS
git clone <this-repo-url> ~/nerdtools

# 2. Install Claude Code (https://docs.anthropic.com/claude-code)

# 3. LLM-driven setup
cd ~/nerdtools && claude
> "Read setup/ and walk me through. Skip steps already done."
```

See [`setup/README.md`](setup/README.md) for full details.

## Architecture

`zsh/entry.sh` is the **canonical contract** — identical on every machine, hardcoded paths, defines what tools and env the shell expects. `setup/` describes one tested recipe to make a machine satisfy that contract.

Cross-platform determinism: setup commands differ per OS (apt vs brew), but the resulting environment is identical because entry.sh is the same everywhere.

```
Setup recipe (varies by OS) ──► env satisfies entry.sh ──► identical zsh experience
```

## Per-machine override

Anything not safe to sync (API keys, work-only env, host-specific aliases) lives in `~/.config/nerdtools/local.zsh` (outside `~/nerdtools/`). `entry.sh` sources it at the very end if present.

## Components

- **Neovim** — see [`nvim/readme.md`](nvim/readme.md). Lazy-loaded plugins, LSPs for 15+ languages.
- **GeekCaps** — Karabiner config in Nim. Build with `cd geekCaps && nimble configure`.
- **Claude Code** — agents, slash commands, hooks under [`claude/`](claude/). Loaded by Claude Code from `~/.claude/`.

## Notes

- `~/nerdtools/` is synced via Syncthing. Edits propagate to all paired machines.
- `mise.toml` at the repo root pins `ruby = "3.4.2"` for the project. Setup trusts it once via `mise trust ~/nerdtools/mise.toml`.
