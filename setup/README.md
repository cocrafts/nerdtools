# nerdtools setup

**Canonical contract**: [`../zsh/entry.sh`](../zsh/entry.sh) on Unix, and its Windows counterpart [`../pwsh/entry.ps1`](../pwsh/entry.ps1). The setup recipes in this directory exist to make a machine satisfy that contract.

## How it works

```
Setup recipe (varies by OS) ──► env satisfies entry.sh ──► identical zsh experience
```

Setup commands differ between Linux/macOS, but the resulting environment is identical because `entry.sh` is the same on every machine. Cross-platform determinism comes from the contract, not from forcing every platform to use the same install commands.

Windows is native (PowerShell 7, not WSL): it satisfies the same intent through a parallel contract, `pwsh/entry.ps1`. Each section below has a `## Windows` subsection with the scoop/PowerShell equivalent of the Unix commands.

## Quick start

1. **Manual bootstrap** ([00-prerequisites.md](00-prerequisites.md)): install git, clone nerdtools, install Claude Code.
2. **LLM-driven** (sections 01–06): in Claude Code, in `~/nerdtools`:

   > *"Read setup/ and walk me through. Skip steps already done. Start from section 01."*

The LLM reads each section and runs the platform-appropriate commands. Sections are idempotent — safe to re-run.

## Sections

| #  | File                                       | What                                    |
| -- | ------------------------------------------ | --------------------------------------- |
| 00 | [00-prerequisites.md](00-prerequisites.md) | Manual: git, nerdtools, Claude Code     |
| 01 | [01-essentials.md](01-essentials.md)       | System packages + base dirs             |
| 02 | [02-mise.md](02-mise.md)                   | mise version manager                    |
| 03 | [03-languages.md](03-languages.md)         | Node, Go, Ruby + npm globals            |
| 04 | [04-tools.md](04-tools.md)                 | Rust toolchain, formatters, linters     |
| 05 | [05-symlinks.md](05-symlinks.md)           | `~/.config/*` → `~/nerdtools/`          |
| 06 | [06-shell.md](06-shell.md)                 | zsh + oh-my-zsh + entry.sh wiring       |

## OS support

| OS                          | Notes                                              |
| --------------------------- | -------------------------------------------------- |
| macOS (Apple Silicon/Intel) | Brew-based install                                 |
| Linux Debian/Ubuntu, WSL2   | apt-based install                                  |
| Windows 10/11 (native)      | scoop + PowerShell 7; contract is `pwsh/entry.ps1` |
| Other distros               | Concepts apply; commands need translation          |

## Files NOT in Syncthing (per-machine)

These live outside `~/nerdtools/`, owned by each machine:

- `~/.zshrc` — sources `~/nerdtools/zsh/entry.sh`
- `~/.config/nerdtools/local.zsh` — per-machine env vars, secrets, work aliases. `entry.sh` sources it if present.

## Handoffs

Some steps need the user (LLM cannot do them). When the LLM hits one of these, it should print **`HANDOFF:`** and wait for the user to confirm "done" before continuing:

| Trigger                            | User action                                                       |
| ---------------------------------- | ----------------------------------------------------------------- |
| `chsh` PAM auth fails (WSL)        | Run `sudo usermod -s /usr/bin/zsh $USER` in another terminal      |
| Default shell change applied       | Restart shell: logout / `wsl --shutdown` / new terminal tab       |
| Sudo password (no TTY for LLM)     | Run the printed command, confirm "done"                           |
| Windows: profile/junctions set     | Close and reopen Wezterm to load `entry.ps1`                       |
| Windows: Smart App Control blocks self-built exes | Decide whether to disable it (irreversible) — see 04-tools |

## Final verification

After all sections, in a fresh shell:

```bash
zsh -i -c '
  set -e
  command -v mise     >/dev/null && echo "mise: ok"
  command -v starship >/dev/null && echo "starship: ok"
  command -v nvim     >/dev/null && echo "nvim: ok"
  [[ -L ~/.config/nvim ]]        && echo "nvim symlink: ok"
'
```

On **Windows**, in a fresh pwsh:

```powershell
pwsh -NoLogo -Command '
  @("mise","starship","nvim") | ForEach-Object {
    if (Get-Command $_ -EA SilentlyContinue) { "$_`: ok" } else { "$_`: MISSING" }
  }
  if (Test-Path "$env:LOCALAPPDATA\nvim") { "nvim junction: ok" }
'
```

If your prompt is starship and `nvim` opens — you're good.
