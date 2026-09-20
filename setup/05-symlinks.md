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
mkdir -p ~/.config/git && ln -sfn ~/nerdtools/conf/git/ignore ~/.config/git/ignore
```

`~/.config/git/ignore` is git's default `core.excludesfile` (same path on Windows).
It carries the patterns every repo needs and no repo should have to declare:
`.cards/`, the arc cards the agent rules put beside a main checkout, and
`**/.claude/settings.local.json`. Only that file is linked — `~/.config/git/`
also holds `allowed-signers`, which is machine-local.

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

The whole `docs/` folder syncs between machines via Syncthing — live WIP docs
shared without committing them. The Syncthing config dir is **not** symlinked
into nerdtools on purpose: `cert.pem`/`key.pem` are the device identity (sharing
them clones the device ID and breaks the protocol) and the index DB is
machine-local. Only the setup recipe lives in the repo.

Folders pair by **folder ID**, not by path — the local path differs per machine:

| Machine | Folder ID | Path |
| --- | --- | --- |
| macOS | `compiler-docs` | `~/metascript/recompiler/docs` |
| Windows | `compiler-docs` | `~\projects\compiler\docs` |

There is **no `.stignore`** — every file in `docs/` syncs, new files included,
nothing to register per file. An earlier setup whitelisted files one by one;
Syncthing never syncs `.stignore` itself, so any leftover per-file copy must be
deleted **by hand on each machine** (re-running `setup.ps1` removes it on
Windows).

Windows — idempotent, safe to re-run (installs syncthing, folder, versioning,
hidden logon task):

```powershell
~/nerdtools/conf/syncthing/setup.ps1
```

macOS — syncthing already runs for nerdtools, so only add the folder at
`http://127.0.0.1:8384`: ID `compiler-docs`, path `~/metascript/recompiler/docs`,
send/receive, trashcan versioning 30 days, shared with the Windows device.

`setup.ps1` creates the folder but never adds a device to it, so **sharing is
manual on both machines** — tick the other device under Edit → Sharing on each
side. Until both have, the folder sits at `globalFiles 0` with nothing to do.

**First merge between two pre-populated folders** (what actually happened
2026-09-03): a file present on both sides with different content resolves by
newer mtime — the loser is preserved next to it as
`NAME.sync-conflict-YYYYMMDD-HHMMSS-DEVICEID.ext`, and files overwritten by the
winner land in `.stversions/` (30-day trashcan). Nothing is lost silently, but
**mtime is not content**: a doc pasted through a chat tool arrived with escaped
markdown (`\*\*bold\*\*`), reflowed lines and CRLF — and a fresh mtime that beat
the genuinely newer edit. Diff conflicts by content (normalize whitespace and
un-escape before comparing), not by timestamp.

`docs/` is inside the recompiler git repo, so `docs/.stfolder/` and
`docs/*.sync-conflict-*` are gitignored there.

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

# git's default core.excludesfile. A file needs SymbolicLink (junctions are directories only),
# so this line needs Developer Mode or an elevated shell — or copy the file and re-copy on change.
New-Item -ItemType Directory -Force -Path "$HOME\.config\git" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.config\git\ignore" -Target "$HOME\nerdtools\conf\git\ignore" | Out-Null

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
