# Unified dev environment for Metacraft developers.

### For Mac user:
- make sure Home Brew installed
- install Ansible with `brew install ansible`
- clone this repo to your home folder (`~/`)
- execute: `ansible-playbook -i hosts.yml macos.yml`

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
- https://github.com/LuaLS/lua-language-server
- https://github.com/TheZoraiz/ascii-image-converter (needed to display image)

### Other notes
- For Kitty, while ssh to Linux client with Nerdtools use `kitty +kitten ssh` instead of `ssh` once to register Kitty with remote system.
- For Wezterm [Configure undercurl](https://wezfurlong.org/wezterm/faq.html?h=undercurl#how-do-i-enable-undercurl-curly-underlines) style for Wezterm.
- Mise, cross-languages version manager https://mise.jdx.dev/lang/bun.html

### Awesome software to consider:
- https://github.com/aristocratos/btop
