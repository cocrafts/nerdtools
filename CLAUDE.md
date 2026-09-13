# CLAUDE.md

Personal dev environment for macOS + Linux. Synced between machines via **git** (commit → push → pull), not auto-sync.

## Layout

- `nvim/` — Neovim config (Lazy.nvim). Entry `init.lua`; plugins `lua/core/*.lua`; LSP `lua/core/lsp/*.lua`; utils `lua/utils/*.lua`
- `geekCaps/` — Nim generator for Karabiner-Elements rules (`rules/*.nim`)
- `setup/` — LLM-executed machine setup, run in order `00`→`06`, starting from `setup/README.md`
- `zsh/entry.sh` — sourced from `~/.zshrc`; per-machine overrides in `~/.config/nerdtools/local.zsh` (not in repo)
- `conf/` — tool configs (ghostty, herdr, lazygit, starship, tmux, ...), symlinked into place per `setup/05-symlinks.md`
- `claude/` — this is `~/.claude` (global Claude Code config)

## Commands

```bash
cd geekCaps && nimble configure   # build + reload Karabiner
stylua nvim/ && selene nvim/      # format + lint Lua
typos                             # spellcheck
```

## Conventions

- Lua: stylua-formatted; keymaps follow `nvim/lua/utils/key.lua`
- New LSP: add `nvim/lua/core/lsp/<lang>.lua`, register in `lsp/init.lua`; formatters/linters in `lsp/none-ls.lua`
- Plugin spec changes need `:Lazy sync`
- Nim: snake_case vars, PascalCase types; each rule module exports one proc
- `setup/*.md` sections: Goal → Preconditions → Steps → Skip rule → Verify → Notes. Idempotent; extend an existing section rather than adding a file. Hardcode paths for tools we install (e.g. mise at `~/.local/bin/mise`); detect brew/apt prefixes
