# 03: Languages (Node, Go, Ruby) + npm globals

## Goal

Node, Go, Ruby installed via mise. Minimal npm globals for Neovim LSPs.

## Linux: Ruby build deps

```bash
sudo apt-get install -y libyaml-dev libffi-dev libreadline-dev zlib1g-dev
```

(macOS: skip — Xcode CLT provides these.)

## All platforms

```bash
~/.local/bin/mise use -g node@lts go@latest ruby@3.4.2

~/.local/bin/mise exec -- npm i -g \
  bash-language-server \
  vscode-langservers-extracted \
  prettier \
  eslint_d
```

## Windows

```powershell
mise use -g node@lts go@latest
mise exec -- npm i -g bash-language-server vscode-langservers-extracted prettier eslint_d
```

Ruby is intentionally omitted on Windows: mise's ruby backend has no native Windows build
(it needs RubyInstaller + MSYS2). Install RubyInstaller only if a specific project needs Ruby.

## Verify

```bash
~/.local/bin/mise exec -- node --version
~/.local/bin/mise exec -- go version
~/.local/bin/mise exec -- ruby --version
```

Windows verify (no Ruby):
```powershell
mise exec -- node --version
mise exec -- go version
```

## Notes

- `mise use -g` is idempotent — no-op if version already set.
- Ruby builds from source on Linux (~5–10 min first time).
- The 4 npm globals back: bash LSP, JSON/CSS/HTML/ESLint LSPs, prettier formatter, eslint_d linter.
- Optional npm packages (uncomment as needed): `graphql-language-service-cli`, `stylelint`, `write-good`, `pm2`, `@metacraft/cli`.
- If `fnm` or `nvm` is on the machine, remove their shell init from `~/.bashrc` to avoid `PATH` conflicts with mise's node.
