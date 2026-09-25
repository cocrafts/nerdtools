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
skills. Codex points at the same `CLAUDE.md` and skill folders. Do not copy them
into Codex-specific versions.

`~/.claude` itself stays a **real directory**, never a link to the repo: it holds
`.credentials.json`, `history.jsonl`, `sessions/`, `projects/`, `file-history/`,
and installed `plugins/` — machine-local state that must not enter git. Link the
tracked items into it one by one, so a new tracked file is one more line here:

```bash
mkdir -p ~/.claude/skills ~/.codex ~/.agents/skills
printf '@~/nerdtools/claude/CLAUDE.md\n' > ~/.claude/CLAUDE.md
ln -sfn ~/nerdtools/claude/statusline.sh ~/.claude/statusline.sh
ln -sfn ~/nerdtools/claude/commands      ~/.claude/commands
ln -sfn ~/nerdtools/claude/scripts       ~/.claude/scripts
ln -sfn ~/nerdtools/claude/themes        ~/.claude/themes
ln -sfn ~/nerdtools/claude/CLAUDE.md     ~/.codex/AGENTS.md

for skill in ~/nerdtools/claude/skills/*; do
  [ -f "$skill/SKILL.md" ] || continue
  ln -sfn "$skill" ~/.claude/skills/"$(basename "$skill")"
  ln -sfn "$skill" ~/.agents/skills/"$(basename "$skill")"
done

commitHook=~/nerdtools/claude/hooks/commit-msg
for repo in ~/metascript/{recompiler,yoga,void,neon,ion,lightcube}; do
  [ -e "$repo/.git" ] || continue
  hookDir=$(git -C "$repo" rev-parse --path-format=absolute --git-path hooks)
  mkdir -p "$hookDir"
  ln -sfn "$commitHook" "$hookDir/commit-msg"
done
```

The hook loop asks Git for each repository's effective hook directory instead of
changing `core.hooksPath`. Existing repository hooks remain active, and linked
worktrees inherit the hook from their common Git directory.

`~/.claude/CLAUDE.md` is a **real file, not a symlink** — one `@` import of the shared
config, then room for rules that belong to this machine alone. Claude Code expands `@`,
so the import is its own sanctioned mechanism, and the machine-local half stops needing
the hand-merge `settings.json` still needs. That file is untracked by construction: a
rule meant for every machine goes in `claude/CLAUDE.md`, in git.

Two `@` facts, measured on Windows 2026-09-20 with `claude -p` against a marker file.
In the **user-level** `~/.claude/CLAUDE.md`, `@~/path` expands; a Windows absolute path
(`@C:\...`) does not. In a **project** `CLAUDE.md`, only a target inside the project
expands — one pointing outside is left as literal text, silently. Hence `~/` above, and
no project file imports across the tree.

Dropping a skill upstream leaves a dangling link behind, so prune before linking:
`find ~/.claude/skills ~/.agents/skills -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \;`.

`settings.json` is **merged by hand, never symlinked**. Claude Code reads one
user-level `settings.json`, and part of it is machine-specific — the
`rexa post claude` hooks only make sense where Rexa is installed. The repo's
`claude/settings.json` carries the shared keys only; fold them into the live file
on each machine, which lets the repo win on any key it declares:

```bash
jq -s '.[0] * .[1]' ~/.claude/settings.json ~/nerdtools/claude/settings.json   > ~/.claude/settings.new && mv ~/.claude/settings.new ~/.claude/settings.json
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

## oh-my-pi (omp)

`~/.omp/agent` stays a **real directory** for the same reason `~/.claude` does: it holds
`agent.db`, the auth store, plus session transcripts and caches. Link the tracked files
in one by one — `extensions/` excepted: everything in it is tracked, so the whole
directory is one link and a new extension needs no new line.

```bash
mkdir -p ~/.omp/agent
ln -sfn ~/nerdtools/omp/config.yml ~/.omp/agent/config.yml
ln -sfn ~/nerdtools/omp/AGENTS.md  ~/.omp/agent/AGENTS.md
ln -sfn ~/nerdtools/omp/extensions ~/.omp/agent/extensions
mkdir -p ~/.omp/plugins
ln -sfn ~/nerdtools/omp/plugins/package.json ~/.omp/plugins/package.json
ln -sfn ~/nerdtools/omp/plugins/bun.lock     ~/.omp/plugins/bun.lock
(
  cd ~/.omp/plugins
  bun install --frozen-lockfile
)
omp plugin doctor
```

On Windows use the PowerShell block below — under Git Bash, `ln -sfn` silently copies
the file instead of linking it unless `MSYS=winsymlinks:nativestrict` is exported, and a
copy drifts from the repo without ever saying so.

Unlike Claude Code's `settings.json`, `config.yml` is symlinked outright — nothing in it
is machine-specific, because credentials live in `agent.db` and `.env`, not here.

The plugin dependency manifest and Bun lockfile are shared; `node_modules/`, caches, and
`omp-plugins.lock.json` stay local. The runtime lock can contain plugin settings, including
secrets. With no runtime entry, an installed dependency loads enabled with its default features.
`bun install --frozen-lockfile` restores the exact package graph; `omp plugin doctor` validates it.

`~/.omp/agent/AGENTS.md` is the one user-level instruction file omp keeps, and it outranks
`~/.claude/CLAUDE.md`. It is deliberately a wrapper: its first line imports
`~/.claude/CLAUDE.md`, which imports the shared config in turn, and the rest is what omp
must do by hand because it cannot read Claude Code's own wiring — where memory lives, and
that a subdirectory may carry its own `CLAUDE.md`. Skills need no line here; omp reads
`~/.agents/skills` natively.

It imports the wrapper rather than the repo file so that a rule written for this machine
reaches both agents from one place. The two hops expand — measured 2026-09-20, `omp -p`
returning a value that only exists in `claude/CLAUDE.md`.

**Codex does not get this treatment.** It has no `@` import
([openai/codex#17401](https://github.com/openai/codex/issues/17401) is still open), so a
wrapper there would ship the model one literal `@` line and silently drop every shared
rule. `~/.codex/AGENTS.md` stays a hard symlink to `claude/CLAUDE.md`, so Codex goes
without the adapters and without the machine-local half the other two get through the
wrapper. The rule that decides: an agent that expands `@` gets a wrapper, an
agent that does not gets the symlink — never a copy of the content. Claude Code expands
`@`, so it is on the wrapper side too.

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
Run this block in **pwsh 7** (`pwsh`): with Developer Mode on, its `SymbolicLink` lines
create file links without elevation.

```powershell
# entry.ps1 sets XDG_CONFIG_HOME=~/.config, so Neovim reads ~/.config/nvim (like Unix).
New-Item -ItemType Junction -Force -Path "$HOME\.config\nvim"     -Target "$HOME\nerdtools\nvim" | Out-Null
# Also junction the native path as a fallback for launches without that env (e.g. Neovide from Explorer).
New-Item -ItemType Junction -Force -Path "$env:LOCALAPPDATA\nvim" -Target "$HOME\nerdtools\nvim" | Out-Null

# Wezterm reads ~/.config on Windows too
New-Item -ItemType Junction -Force -Path "$HOME\.config\wezterm" -Target "$HOME\nerdtools\conf\wezterm" | Out-Null

# Alacritty ignores ~/.config on Windows and reads only %APPDATA%\alacritty
New-Item -ItemType Junction -Force -Path "$env:APPDATA\alacritty" -Target "$HOME\nerdtools\conf\alacritty" | Out-Null
# Its default shell is Windows PowerShell 5.1, which skips entry.ps1 (no XDG_CONFIG_HOME, so herdr
# falls back to %APPDATA%\herdr). windows.toml opens pwsh 7 like Wezterm and swaps the font; alacritty.toml
# imports this path after defaults.toml, so it overrides; macOS/Linux have no such file and keep defaults.toml.
New-Item -ItemType Directory -Force -Path "$HOME\.config\nerdtools" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.config\nerdtools\alacritty.toml" -Target "$HOME\nerdtools\conf\alacritty\windows.toml" | Out-Null

# git's default core.excludesfile. A file needs SymbolicLink (junctions are directories only),
# so this line needs Developer Mode or an elevated shell — or copy the file and re-copy on change.
New-Item -ItemType Directory -Force -Path "$HOME\.config\git" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.config\git\ignore" -Target "$HOME\nerdtools\conf\git\ignore" | Out-Null

# ~/.claude stays a real directory; only the tracked items are linked into it.
New-Item -ItemType Directory -Force -Path "$HOME\.claude\skills", "$HOME\.codex", "$HOME\.agents\skills" | Out-Null
Set-Content -Path "$HOME\.claude\CLAUDE.md" -Value '@~/nerdtools/claude/CLAUDE.md' -Encoding utf8NoBOM
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.claude\statusline.sh" -Target "$HOME\nerdtools\claude\statusline.sh" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.claude\commands"      -Target "$HOME\nerdtools\claude\commands" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.claude\scripts"       -Target "$HOME\nerdtools\claude\scripts" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.claude\themes"        -Target "$HOME\nerdtools\claude\themes" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.codex\AGENTS.md"      -Target "$HOME\nerdtools\claude\CLAUDE.md" | Out-Null

New-Item -ItemType Directory -Force -Path "$HOME\.omp\agent" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.omp\agent\config.yml" -Target "$HOME\nerdtools\omp\config.yml" | Out-Null
New-Item -ItemType Junction -Force -Path "$HOME\.omp\agent\extensions" -Target "$HOME\nerdtools\omp\extensions" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.omp\agent\AGENTS.md"  -Target "$HOME\nerdtools\omp\AGENTS.md" | Out-Null
New-Item -ItemType Directory -Force -Path "$HOME\.omp\plugins" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.omp\plugins\package.json" -Target "$HOME\nerdtools\omp\plugins\package.json" | Out-Null
New-Item -ItemType SymbolicLink -Force -Path "$HOME\.omp\plugins\bun.lock"     -Target "$HOME\nerdtools\omp\plugins\bun.lock" | Out-Null
Push-Location "$HOME\.omp\plugins"
bun install --frozen-lockfile
Pop-Location
omp plugin doctor

Get-ChildItem "$HOME\nerdtools\claude\skills" -Directory | Where-Object {
  Test-Path "$($_.FullName)\SKILL.md"
} | ForEach-Object {
  New-Item -ItemType SymbolicLink -Force -Path "$HOME\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
  New-Item -ItemType Junction     -Force -Path "$HOME\.agents\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
```

- Junctions replace the whole target dir, so they are idempotent with `-Force`.
- The file symlinks (`AGENTS.md`, `statusline.sh`, `omp/plugins/*`) need Developer Mode
  and a pwsh 7 shell. `~/.agents/skills` stays junctions so Codex works without it.
- Keep the two Codex fallback keys above in `$HOME\.codex\config.toml`; that file remains machine-local.
- Apps that read `%APPDATA%`/`%LOCALAPPDATA%` instead of `~/.config` on Windows (e.g. lazygit)
  need their own junction to the platform path; add per-app as needed.

## Verify

```bash
for link in ~/.config/nvim ~/.config/alacritty ~/.config/wezterm ~/.config/nushell ~/.config/tmux \
            ~/.aider.conf.yml ~/revive.toml ~/.config/lazygit/config.yml ~/.config/zls.json \
            ~/.config/herdr/config.toml ~/.claude/commands ~/.claude/statusline.sh \
            ~/.omp/plugins/package.json ~/.omp/plugins/bun.lock ~/.codex/AGENTS.md; do
  if [[ -L "$link" && -e "$link" ]]; then
    printf "✓ %-40s -> %s\n" "$link" "$(readlink "$link")"
  else
    printf "✗ %-40s MISSING\n" "$link"
  fi
done

head -1 ~/.claude/CLAUDE.md   # a real file, must print: @~/nerdtools/claude/CLAUDE.md
```

## Notes

- `ln -sfn` is idempotent (force-overwrite existing symlink, no-deref).
- `~/.claude` is a real directory holding live credentials, sessions, history, and
  installed plugins. Only `statusline.sh`, `commands/`, `scripts/`, `themes/`, and
  each `skills/<name>/` are linked back to the repo; `CLAUDE.md` is a real file that
  imports the repo's, and `settings.json` is merged by hand.
