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

## Windows

```powershell
# Rust — GNU toolchain: self-contained linker, avoids the ~6GB VS C++ Build Tools that the
# MSVC target requires. See the Application Control gotcha below before building.
scoop install rustup zig
rustup toolchain install stable-x86_64-pc-windows-gnu --profile minimal
rustup default stable-x86_64-pc-windows-gnu
rustup component add rust-analyzer

# Cross-platform tools via mise (same github backend as Unix; auto-detects the Windows asset)
mise use -g bat@latest stylua@latest starship@latest taplo@latest typos@latest
mise use -g github:Kampfkarren/selene github:nushell/nushell
mise use -g lazygit@latest shfmt@latest gofumpt@latest
```

- **zig** is a drop-in C/C++ compiler (`zig cc`) for crates/plugins that build C without MSVC.
  The Neovim config uses it for Treesitter parser compilation on Windows, and disables Lazy's
  luarocks there (image.nvim uses `magick_cli`, so no rock is needed).
- For image.nvim's preview, install ImageMagick via **winget** (`winget install ImageMagick.ImageMagick`) —
  scoop's `imagemagick` is currently broken (its `innounp` dependency fails to download).
- If a `mise use -g` tool has no Windows release, fall back to `scoop install <tool>`.

> **⚠️ Gotcha — Application Control (Smart App Control / WDAC).** If enabled, running a
> *self-compiled* unsigned `.exe` (e.g. `cargo build` output) is blocked: "An Application Control
> policy has blocked this file". This is a **machine policy**, not a build error. Local dev
> requires turning Smart App Control off (Settings → Privacy & security → Smart App Control) —
> note it **cannot be re-enabled** without reinstalling Windows.

## Verify

```bash
for t in rust-analyzer bat stylua starship taplo typos selene nu neocmakelsp lazygit shfmt gofumpt revive; do
  command -v "$t" >/dev/null 2>&1 && echo "$t: ok" || echo "$t: MISSING"
done
```

Windows verify:
```powershell
foreach ($t in "rust-analyzer","cargo","zig","bat","stylua","starship","taplo","typos","selene","nu","lazygit","shfmt","gofumpt") {
  if (Get-Command $t -EA SilentlyContinue) { "$t: ok" } else { "$t: MISSING" }
}
```

Expect 13 lines all `ok` (after section 06 wires `entry.sh` and PATH includes mise shims).

## Notes

- `--no-modify-path` for rustup: `entry.sh` adds `~/.cargo/bin` to `PATH` if it exists. Letting rustup also append risks duplicate entries.
- `mise use -g github:owner/repo` installs the latest github release, auto-detecting platform/arch. No manual arch detection needed.
- `mise use -g` and `go install` are both idempotent — safe to re-run.
- All tools land in mise shims (`~/.local/share/mise/shims/`) except `rust-analyzer` (`~/.cargo/bin/`).
