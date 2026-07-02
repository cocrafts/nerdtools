# 04: Developer tools

## Goal

Rust toolchain + formatters + linters + LSPs.

## All platforms

```bash
# Rust toolchain (idempotent — installer skips if cargo present)
[[ -x ~/.cargo/bin/cargo ]] || \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

~/.cargo/bin/rustup component add rust-analyzer

# Tools via mise (auto-handles platform/arch)
~/.local/bin/mise use -g \
  bat@latest \
  stylua@latest \
  starship@latest \
  taplo@latest \
  typos@latest \
  github:Kampfkarren/selene \
  github:nushell/nushell \
  github:Decodetalkers/neocmakelsp

# Defensive: mise's github backend sometimes loses +x on zip extracts (e.g. selene).
# chmod every binary in mise github installs.
find ~/.local/share/mise/installs/github-* -type f -exec chmod +x {} \; 2>/dev/null

# Go-installed tools (use mise's Go)
~/.local/bin/mise exec -- bash -c '
  go install github.com/mgechev/revive@latest
  go install mvdan.cc/gofumpt@latest
  go install mvdan.cc/sh/v3/cmd/shfmt@latest
  go install github.com/jesseduffield/lazygit@latest
'
~/.local/bin/mise reshim
```

## Verify

```bash
for t in rust-analyzer bat stylua starship taplo typos selene nu neocmakelsp lazygit shfmt gofumpt revive; do
  command -v "$t" >/dev/null 2>&1 && echo "$t: ok" || echo "$t: MISSING"
done
```

Expect 13 lines all `ok` (after section 06 wires `entry.sh` and PATH includes mise shims).

## Notes

- `--no-modify-path` for rustup: `entry.sh` adds `~/.cargo/bin` to `PATH` if it exists. Letting rustup also append risks duplicate entries.
- `mise use -g github:owner/repo` installs the latest github release, auto-detecting platform/arch. No manual arch detection needed.
- `mise use -g` and `go install` are both idempotent — safe to re-run.
- All tools land in mise shims (`~/.local/share/mise/shims/`) except `rust-analyzer` (`~/.cargo/bin/`).
