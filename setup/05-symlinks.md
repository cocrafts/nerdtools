# 05: Config symlinks

## Goal

`~/.config/*` and a few `~/<dotfile>`s point at synced configs in `~/nerdtools/`.

## All platforms

```bash
ln -sfn ~/nerdtools/nvim                ~/.config/nvim
ln -sfn ~/nerdtools/conf/alacritty      ~/.config/alacritty
ln -sfn ~/nerdtools/conf/wezterm        ~/.config/wezterm
ln -sfn ~/nerdtools/conf/aider.conf.yml ~/.aider.conf.yml
ln -sfn ~/nerdtools/conf/nushell        ~/.config/nushell
ln -sfn ~/nerdtools/conf/revive.toml    ~/revive.toml
ln -sfn ~/nerdtools/conf/lazygit.yml    ~/.config/lazygit/config.yml
ln -sfn ~/nerdtools/conf/zls.json       ~/.config/zls.json
ln -sfn ~/nerdtools/conf/tmux           ~/.config/tmux
mkdir -p ~/.config/herdr && ln -sfn ~/nerdtools/conf/herdr/config.toml ~/.config/herdr/config.toml
```

`~/.config/herdr/` also holds machine-local runtime state (logs, sockets, `session.json`), so only the `config.toml` file is symlinked, not the whole directory.

The `vim-herdr-navigation` plugin (seamless `Ctrl+h/j/k/l` across herdr panes and Neovim splits) is vendored at `~/nerdtools/conf/herdr/vim-herdr-navigation`. Its `config.toml` keybinds and the Neovim side sync via git, but linking it into herdr is machine-local — run once per machine (needs `jq`):

```bash
herdr plugin link ~/nerdtools/conf/herdr/vim-herdr-navigation && herdr server reload-config
```

## Windows

Windows uses **directory junctions** instead of `ln -sfn`. Junctions need no admin (unlike
`SymbolicLink`), and the target app sees the real repo files — so Wezterm hot-reloads natively.

```powershell
# entry.ps1 sets XDG_CONFIG_HOME=~/.config, so Neovim reads ~/.config/nvim (like Unix).
New-Item -ItemType Junction -Force -Path "$HOME\.config\nvim"     -Target "$HOME\nerdtools\nvim" | Out-Null
# Also junction the native path as a fallback for launches without that env (e.g. Neovide from Explorer).
New-Item -ItemType Junction -Force -Path "$env:LOCALAPPDATA\nvim" -Target "$HOME\nerdtools\nvim" | Out-Null

# Wezterm reads ~/.config on Windows too
New-Item -ItemType Junction -Force -Path "$HOME\.config\wezterm" -Target "$HOME\nerdtools\conf\wezterm" | Out-Null
```

- Junctions replace the whole target dir, so they are idempotent with `-Force`.
- Same rule as below: do **not** junction `~/.claude`.
- Apps that read `%APPDATA%`/`%LOCALAPPDATA%` instead of `~/.config` on Windows (e.g. lazygit)
  need their own junction to the platform path; add per-app as needed.

## Verify

```bash
for link in ~/.config/nvim ~/.config/alacritty ~/.config/wezterm ~/.config/nushell ~/.config/tmux \
            ~/.aider.conf.yml ~/revive.toml ~/.config/lazygit/config.yml ~/.config/zls.json \
            ~/.config/herdr/config.toml; do
  if [[ -L "$link" && -e "$link" ]]; then
    printf "✓ %-40s -> %s\n" "$link" "$(readlink "$link")"
  else
    printf "✗ %-40s MISSING\n" "$link"
  fi
done
```

## Notes

- `ln -sfn` is idempotent (force-overwrite existing symlink, no-deref).
- **Do NOT symlink `~/.claude` to `~/nerdtools/claude`.** `~/.claude/` holds live Claude Code session data (credentials, sessions, history). Replacing it with a symlink destroys session state.
