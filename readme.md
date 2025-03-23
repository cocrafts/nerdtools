# Unified dev environment for Metacraft developers.

### For Mac user:
- make sure Home Brew installed
- install Ansible with `brew install ansible`
- clone this repo to your home folder (`~/`)
- execute: `ansible-playbook -i hosts.yml macos.yml`

#### Pre-requisites:
- Install [Homebrew](https://brew.sh/) manually via: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` command
- Install [Ansible](https://www.ansible.com/) using `brew`: `brew install ansible`
- Install [Starship](https://starship.rs/) (optional) via `brew`: `brew install starship`

### For remote Linux client:
- replace ip-address under `hosts.yml`
- make sure host machine configured be able to ssh to replaced "ip-address"
- make sure Ansible client existed on remote client
- execute `ansible-playbook -i hosts.yml linux.yml`
- run: `chsh -s $(which zsh)` to set zsh as default

### For nvim user
- brew install llvm --with-toolchain (clang, clang-tidy, clang-format)
- pip3 install ruff
- pip3 install mypy
- pip3 install jsonls
- pip3 install pyright
- pip3 install codespell
- https://github.com/LuaLS/lua-language-server (included in macOS)
- [ascii-image-converter](https://github.com/TheZoraiz/ascii-image-converter) (needed to display image)

### Those `lsp` better manually installed rather than using `mason`)
- [wgsl-analyzer](https://github.com/wgsl-analyzer/wgsl-analyzer) (shader language)
- [hurl](https://hurl.dev/docs/installation.html) (curl like cli)
- [lua-language-server](https://github.com/LuaLS/lua-language-server) (cmd: `brew install lua-language-server`)
- [rust-analyzer](https://rust-analyzer.github.io/book/installation.html) (cmd: `rustup component add rust-src`, included in macOS Ansible)
- [gopls](https://github.com/golang/tools/tree/master/gopls) for Go lsp
- [zls](https://github.com/zigtools/zls) for Zig lsp
- [nph](https://github.com/arnetheduck/nph) as Nim formatter
- for Swift: `brew install swiftlint`, `brew install swiftformat`

### Other notes
- For Kitty, while ssh to Linux client with Nerdtools use `kitty +kitten ssh` instead of `ssh` once to register Kitty with remote system.
- For Wezterm [Configure undercurl](https://wezfurlong.org/wezterm/faq.html?h=undercurl#how-do-i-enable-undercurl-curly-underlines) style for Wezterm.
- Mise, cross-languages version manager https://mise.jdx.dev/lang/bun.html

### Awesome software to consider:
- https://github.com/aristocratos/btop

