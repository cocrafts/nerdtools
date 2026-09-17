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

## Claude Code and Codex

`~/nerdtools/claude/` is the canonical source for shared agent instructions and
skills. Claude Code uses that directory directly; Codex points at the same
`CLAUDE.md` and skill folders. Do not copy them into Codex-specific versions.

Before linking on a new machine, inspect any existing real `~/.claude` directory
and merge anything worth keeping. Once it is safe to replace, run:

```bash
mkdir -p ~/.codex ~/.agents/skills
ln -sfn ~/nerdtools/claude ~/.claude
ln -sfn ~/nerdtools/claude/CLAUDE.md ~/.codex/AGENTS.md

for skill in ~/nerdtools/claude/skills/*; do
  [ -f "$skill/SKILL.md" ] && [ ! -L "$skill" ] || continue
  ln -sfn "$skill" ~/.agents/skills/"$(basename "$skill")"
done
```

Keep `~/.codex/config.toml` machine-local because it contains generated plugin,
desktop, MCP, and trust state. Add these top-level keys before the first TOML
table so Codex discovers project `CLAUDE.md` files without parallel `AGENTS.md`
copies:

```toml
project_doc_fallback_filenames = ["CLAUDE.md"]
project_doc_max_bytes = 65536
```

For a repository with shared Claude/Codex skills, keep the canonical skills at
`.claude/skills/<name>/SKILL.md` and add this relative link once:

```bash
mkdir -p .agents
ln -sfn ../.claude/skills .agents/skills
```

A shared `SKILL.md` frontmatter should contain `name` and `description`. Put
invocation phrases in `description`; do not add a separate `trigger` key.

The `vim-herdr-navigation` plugin (seamless `Ctrl+h/j/k/l` across herdr panes and Neovim splits) is vendored at `~/nerdtools/conf/herdr/vim-herdr-navigation`. Its `config.toml` keybinds and the Neovim side sync via git, but linking it into herdr is machine-local — run once per machine (needs `jq`):

```bash
herdr plugin link ~/nerdtools/conf/herdr/vim-herdr-navigation && herdr server reload-config
```

## Syncthing (compiler docs)

`~/projects/compiler/docs` syncs between machines via Syncthing — per-file, WIP
docs without committing them. The Syncthing config dir is **not** symlinked
into nerdtools on purpose: `cert.pem`/`key.pem` are the device identity (sharing
them clones the device ID and breaks the protocol) and the index DB is
machine-local. Only the setup recipe lives in the repo.

Windows — idempotent, safe to re-run (installs syncthing, folder, versioning,
`.stignore`, hidden logon task):

```powershell
~/nerdtool/conf/syncthing/setup.ps1
```

macOS — syncthing is already running for nerdtools, so only pair the folder:

1. GUI at `http://127.0.0.1:8384` → add folder, **Folder ID must be `compiler-docs`**,
   path `~/projects/compiler/docs`, send/receive, and share it with the Windows
   device ID printed by the setup script.
2. Accept the Windows device under "New Device" and share back.
3. Create the same `.stignore` in the folder root (Syncthing never syncs
   `.stignore` itself). Negations MUST come before the catch-all — Syncthing is
   first-match-wins, unlike gitignore:

   ```
   !/NIM-REF.md
   *
   ```

4. On Windows, accept the Mac's device ID in the GUI to finish pairing.

Verified state: `compiler-docs` idle, 1 file tracked, trashcan versioning 30 days.

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

# Inspect and merge existing real paths before replacing them.
New-Item -ItemType Junction -Force -Path "$HOME\.claude" -Target "$HOME\nerdtools\claude" | Out-Null
New-Item -ItemType Directory -Force -Path "$HOME\.codex", "$HOME\.agents\skills" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.codex\AGENTS.md" -Target "$HOME\nerdtools\claude\CLAUDE.md" | Out-Null

Get-ChildItem "$HOME\nerdtools\claude\skills" -Directory | Where-Object {
  (Test-Path "$($_.FullName)\SKILL.md") -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
} | ForEach-Object {
  New-Item -ItemType Junction -Force -Path "$HOME\.agents\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
```

- Junctions replace the whole target dir, so they are idempotent with `-Force`.
- The `AGENTS.md` file symlink requires Windows Developer Mode or an elevated shell.
- Keep the two Codex fallback keys above in `$HOME\.codex\config.toml`; that file remains machine-local.
- Apps that read `%APPDATA%`/`%LOCALAPPDATA%` instead of `~/.config` on Windows (e.g. lazygit)
  need their own junction to the platform path; add per-app as needed.

## Verify

```bash
for link in ~/.config/nvim ~/.config/alacritty ~/.config/wezterm ~/.config/nushell ~/.config/tmux \
            ~/.aider.conf.yml ~/revive.toml ~/.config/lazygit/config.yml ~/.config/zls.json \
            ~/.config/herdr/config.toml ~/.claude ~/.codex/AGENTS.md; do
  if [[ -L "$link" && -e "$link" ]]; then
    printf "✓ %-40s -> %s\n" "$link" "$(readlink "$link")"
  else
    printf "✗ %-40s MISSING\n" "$link"
  fi
done
```

## Notes

- `ln -sfn` is idempotent (force-overwrite existing symlink, no-deref).
- `~/.claude` also contains live credentials, sessions, and history under the
  nerdtools working tree. Those runtime paths must stay ignored; only explicitly
  tracked configuration and `claude/skills/` are replicated by git.
