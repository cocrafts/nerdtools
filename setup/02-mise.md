# 02: mise (universal version manager)

## Goal

`mise` available at `~/.local/bin/mise` (the canonical path hardcoded in `entry.sh`).

## All platforms

```bash
mkdir -p ~/.local/bin

[[ -x ~/.local/bin/mise ]] || curl https://mise.run | sh

[[ -f ~/nerdtools/mise.toml ]] && ~/.local/bin/mise trust ~/nerdtools/mise.toml
```

## Verify

```bash
~/.local/bin/mise --version
```

## Notes

- The `[[ -x ]] ||` guard prevents re-download if mise is already installed.
- Don't `brew install mise` on macOS — keep the canonical path consistent across all machines.
- After this section, mise is callable as `~/.local/bin/mise` but not yet in `PATH` until `entry.sh` is sourced (section 06). Subsequent sections use the absolute path.
