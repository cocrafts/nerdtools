# 06: Shell (zsh + oh-my-zsh + entry.sh wiring)

## Goal

zsh as default shell. oh-my-zsh + plugins installed. `~/.zshrc` sources `entry.sh`.

## All platforms — oh-my-zsh + ~/.zshrc

```bash
[[ -d ~/.oh-my-zsh ]] || \
  git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

[[ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

[[ -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

touch ~/.zshrc
grep -q "nerdtools/zsh/entry.sh" ~/.zshrc || \
  echo 'source ~/nerdtools/zsh/entry.sh' >> ~/.zshrc
```

## Default shell

### Linux (apt zsh)

```bash
chsh -s /usr/bin/zsh
```

If `chsh` fails with `PAM: Authentication failure` (common on WSL):

> **HANDOFF**: in another terminal, run `sudo usermod -s /usr/bin/zsh $USER`, then return.

### macOS (brew zsh)

```bash
ZSH_PATH="$(brew --prefix)/bin/zsh"
grep -q "^${ZSH_PATH}$" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
chsh -s "$ZSH_PATH"
```

## Windows (PowerShell 7 — the `entry.ps1` contract)

Windows doesn't run zsh. Its contract counterpart is **`pwsh/entry.ps1`**, loaded from the
PowerShell 7 profile. Everything `entry.sh` provides (PATH, starship/zoxide/mise init, history
prediction, aliases) is mirrored there — so the *experience* matches even though the shell differs.

```powershell
# PowerShell 7 (skip if already installed)
scoop install pwsh

# Point the pwsh profile at the repo's entry.ps1 (source of truth stays in the repo)
$profilePath = & pwsh -NoProfile -Command '$PROFILE'
New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
Set-Content -Path $profilePath -Encoding utf8 -Value '. "$HOME\nerdtools\pwsh\entry.ps1"'
```

- **No oh-my-zsh**: PSReadLine (built-in) gives autosuggestions + history search; `posh-git` is
  optional for git status in the prompt.
- `entry.ps1` sources `~/.config/nerdtools/local.ps1` if present (counterpart of `local.zsh`).
- Wezterm's `default_prog` launches `pwsh.exe`, so a new terminal lands in this profile.

> **HANDOFF (Windows)**: close and reopen Wezterm (or open a new pwsh tab) to load `entry.ps1`.

Windows verify (fresh pwsh):
```powershell
pwsh -NoLogo -Command 'starship --version; mise --version; (Get-Command nvim).Source'
```

## Per-machine override (optional)

```bash
# entry.sh sources this file at the very end if it exists. Per-machine, NOT in Syncthing.
$EDITOR ~/.config/nerdtools/local.zsh
```

Example contents:
```zsh
export ANTHROPIC_API_KEY="..."
export JAVA_HOME="$HOME/work/jdk-21"
alias work="cd ~/work && code ."
```

## HANDOFF: restart shell

After this section, restart shell to load `entry.sh`:
- **WSL**: from Windows PowerShell, `wsl --shutdown`, then reopen the WSL terminal.
- **macOS**: close Terminal/iTerm tab, open a new one.
- **Linux GUI**: log out and log back in (or open a new terminal).

## Verify (after restart)

```bash
zsh -i -c 'echo "shell=$SHELL ZSH=$ZSH_VERSION mise=$(command -v mise) starship=$(command -v starship)"'
```

Expected: shell ends in `/zsh`, `ZSH_VERSION` non-empty, both `mise` and `starship` resolve.

## Notes

- `entry.sh` ordering matters: env → brew shellenv → mise activate → oh-my-zsh → tools → llvm. Don't reorder it.
- `keybindings.sh` is sourced by `entry.sh`; pure key bindings, env-agnostic.
- Node is managed by mise (section 03). Don't add zsh-nvm — would conflict.
