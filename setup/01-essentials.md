# 01: System essentials

## Goal

Core CLI tools available system-wide. Base directories created.

## Linux (Debian / Ubuntu)

```bash
mkdir -p ~/Sources/bin ~/Projects ~/.config/lazygit ~/.config/nerdtools

sudo apt-get update
sudo apt-get install -y \
  build-essential flatpak procps \
  python3 python3-pip \
  curl git ripgrep zoxide fzf zsh \
  neovim fd-find jq shellcheck \
  libssl-dev pkg-config libyaml-dev
```

## macOS

```bash
mkdir -p ~/Sources/bin ~/Projects ~/.config/lazygit ~/.config/nerdtools

xcode-select -p >/dev/null 2>&1 || xcode-select --install
brew install \
  ripgrep zoxide fzf zsh neovim fd jq shellcheck \
  openssl pkg-config libyaml
```

## Verify

```bash
zsh --version
nvim --version | head -1
rg --version | head -1
```

## Notes

- `apt-get install -y` and `brew install` are idempotent — safe to re-run.
- On Debian/Ubuntu the `fd` binary is named `fdfind`. Add `alias fd=fdfind` to `~/.config/nerdtools/local.zsh` if you want the short name.
- macOS ships an old `zsh` at `/bin/zsh`. The brew zsh is preferred — section 06 handles the switch.
