# Neovim configuration

Personal Neovim setup, loaded as `~/.config/nvim/` (symlink from setup/05).

## Quick start

```bash
nvim   # First launch auto-installs Lazy.nvim and bootstraps all plugins
```

## Architecture

```
nvim/
├── init.lua                Entry point. Loads utils + core + themes.
├── lazy-lock.json          Lazy.nvim plugin version pins (commit).
├── lua/
│   ├── utils/              Pre-LSP setup: settings, autocmds, keymaps, helpers
│   │   ├── settings.lua    Vim options
│   │   ├── autocmds.lua    Autocommands
│   │   ├── keymaps.lua     Global keymaps
│   │   ├── commands.lua    User commands (:XYZ)
│   │   ├── plugins.lua     ★ Lazy.nvim plugin spec (one big list)
│   │   ├── config.lua      Feature flags (use_lua, use_go, …)
│   │   ├── helper.lua      Shared LSP helpers (e.g. open_lsp_definitions)
│   │   ├── icons.lua       Icon constants
│   │   └── key.lua         Keymap helpers
│   ├── core/               Per-feature module configs (30 files)
│   │   ├── init.lua        Bootstraps Lazy.nvim, loads spec from utils/plugins.lua
│   │   ├── lsp/            ★ Per-language LSP configs (30+ files)
│   │   │   ├── init.lua    LSP-zero setup, on_attach keymaps, dispatch per-lang
│   │   │   ├── mason.lua   Mason ensure_installed
│   │   │   ├── cmp.lua     nvim-cmp completion config
│   │   │   ├── none-ls.lua null-ls / formatters config
│   │   │   ├── guard.lua   Format-on-save (guard.nvim)
│   │   │   └── <lang>.lua  One per language: clang, cmake, elixir, eslint,
│   │   │                   gleam, go, godot, graphql, haxe, html, json, lua-ls,
│   │   │                   meson, metascript, nim, odin, python, ruby-lsp,
│   │   │                   rust, sql, swift, terminal (bash+nushell),
│   │   │                   terraform, toml, typescript-tools, wgsl, zls
│   │   └── <feature>.lua   bufferline, comment, devicons, diff, fold, fzf,
│   │                       gitsigns, graphical, hlchunk, hurl, illuminate,
│   │                       lualine, luasnip, markdown, neo-tree, noice,
│   │                       package-info, rainbow, satellite, surround, tabby,
│   │                       toggleterm, treesitter, whichkey, lastplace, …
│   ├── plugins/
│   │   └── claude/         ★ Custom Claude IDE integration
│   │                       (server, handshake, tools, lockfile, prompt, …)
│   ├── themes/             Theme picker + catppuccin / tokyonight configs
│   ├── snippets/           Custom snippets (in addition to friendly-snippets)
│   └── after/              Filetype overrides, treesitter query patches
└── readme.md               This file
```

★ = the three places you'll touch most.

## Adding a language LSP

1. Create `lua/core/lsp/<lang>.lua` exposing `M.configure(lspconfig)` (see `lua/core/lsp/json.lua` as a small example).
2. Register it in `lua/core/lsp/init.lua` — add `require("core.lsp.<lang>").configure(lspconfig)` inside `M.configure()`.
3. If the LSP is in Mason: add to `lua/core/lsp/mason.lua` `ensure_installed`.
4. If a formatter/linter is needed: wire in `lua/core/lsp/none-ls.lua` or `lua/core/lsp/guard.lua`.
5. Restart Neovim. `:Mason` + `:LspInfo` to verify.

## Adding a plugin

Edit `lua/utils/plugins.lua` (one big list). Each entry is a Lazy.nvim spec.

For non-trivial config, create `lua/core/<plugin-name>.lua` with a `configure()` function and call it from the spec's `config = function() ... end`.

After saving: `:Lazy sync` (or just restart — Lazy auto-checks).

## Feature flags

Some heavy LSPs are gated by `lua/utils/config.lua`. Flip flags per-machine:

```lua
return {
  use_lua = true,
  use_python = true,
  use_clang = true,
  use_go = true,
  use_gleam = false,
  use_elixir = false,
  use_godot = false,
  use_svelte = false,
  use_live_diagnostic = false,
}
```

Use this when a machine doesn't have toolchain X installed (skip the LSP without removing the file).

## LSP / language coverage

| Language       | LSP                              | Formatter / Linter                |
| -------------- | -------------------------------- | --------------------------------- |
| C / C++        | clangd (Mason)                   | clang-format                      |
| CMake          | neocmakelsp                      | —                                 |
| Elixir         | elixir-tools                     | —                                 |
| Gleam          | gleam-language-server            | gleam format                      |
| Go             | gopls (go.nvim)                  | gofumpt, revive                   |
| Godot          | gdscript LSP                     | —                                 |
| GraphQL        | graphql-language-service         | prettier                          |
| Haxe           | haxe-language-server             | —                                 |
| HTML / CSS     | vscode-langservers-extracted     | prettier, stylelint               |
| JSON           | vscode-langservers-extracted     | prettier                          |
| Lua            | lua-language-server              | stylua, selene                    |
| Markdown       | markdownlint, render-markdown    | prettier, write-good              |
| Meson          | meson LSP                        | —                                 |
| Metascript     | custom (see lua/core/lsp/)       | —                                 |
| Nim            | nim-langserver                   | nph                               |
| Nushell        | nu --lsp                         | —                                 |
| Odin           | ols                              | —                                 |
| Python         | pyright + ruff                   | ruff format, mypy                 |
| Ruby           | ruby-lsp                         | rubocop                           |
| Rust           | rust-analyzer (rust-tools.nvim)  | rustfmt                           |
| Shell (bash)   | bash-language-server             | shfmt, shellcheck                 |
| SQL            | sqls (sqls.nvim)                 | —                                 |
| Swift          | sourcekit-lsp                    | swiftformat, swiftlint            |
| Terraform      | terraform-ls                     | terraform fmt                     |
| TOML           | taplo                            | taplo                             |
| TypeScript/JS  | typescript-tools.nvim            | prettier, eslint_d                |
| WGSL           | wgsl_analyzer (disabled)         | —                                 |
| Zig            | zls                              | zig fmt                           |

External CLI tools needed live in [`../setup/04-tools.md`](../setup/04-tools.md) (rust-analyzer, stylua, selene, nu, lazygit, …) and [`../setup/03-languages.md`](../setup/03-languages.md) (npm globals: bash-language-server, vscode-langservers-extracted, prettier, eslint_d).

## Notable features

- **Claude IDE integration** (`lua/plugins/claude/`) — speaks Claude Code's local IDE protocol via a small server. `:Claude*` commands attach Neovim as the editor surface for an active Claude Code session. See `lua/plugins/claude/init.lua`.
- **`flash.nvim`** — `s` to jump anywhere in viewport (replaces vim-sneak).
- **`hurl.nvim`** — run HTTP request files inline (`:HurlRun`).
- **`render-markdown.nvim`** — pretty markdown rendering in normal mode.
- **`smear-cursor.nvim`** — animated cursor trail (subtle, configurable).
- **`hlchunk.nvim`** — highlight current code chunk's indentation context.

## Plugin update / cleanup

```vim
:Lazy sync          " install missing, update existing, clean removed
:Lazy clean         " remove unused
:Lazy log <plugin>  " see git log of a plugin
:Mason              " manage Mason-installed LSPs/formatters
:checkhealth        " general health check + per-plugin checks
```

## Notes

- Plugin specs live in `utils/plugins.lua` (single file, ~350 lines). Considered splitting by category but kept together for grep-ability.
- LSP keymaps (`gd`, `gD`, `gs`, `gS`, `[d`, `]d`, `K`) attach in `lua/core/lsp/init.lua` `on_attach`. Add new ones there.
- Formatting: most languages use **guard.nvim** for format-on-save (config in `lua/core/lsp/guard.lua`). Exceptions go through none-ls.
- The `lazy-lock.json` IS committed — pinned versions across machines. Update intentionally with `:Lazy sync`.
