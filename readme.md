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
- you may want manually install: [starship prompt](https://starship.rs/guide/#%F0%9F%9A%80-installation) 

### For nvim user
- brew install fd
- brew install ripgrep
- brew install jq
- brew install llvm --with-toolchain (clang, clang-tidy, clang-format)
- cargo install typos-cli or brew install typos-cli (typos)
- cargo install neocmakelsp (for .cmake)
- cargo install selene (lua linter, lighting fast)
- cargo install --features lsp --locked taplo-cli (for toml)
- cargo install --git https://github.com/wgsl-analyzer/wgsl-analyzer wgsl_analyzer
- npm install -g eslint_d
- npm install -g write-good
- npm i -g bash-language-server
- pip3 install ruff
- pip3 install mypy

### For Linux user, we may need to manually install those libraries
- brew install efm-langserver
- brew install lua-language-server
- conda install jsonls
- conda install pyright

### Other notes:
- For Kitty, while ssh to Linux client with Nerdtools use `kitty +kitten ssh` instead of `ssh` once to register Kitty with remote system.
- For Wezterm [Configure undercurl](https://wezfurlong.org/wezterm/faq.html?h=undercurl#how-do-i-enable-undercurl-curly-underlines) style for Wezterm.

### For Ubuntu, install these dependency manually (at least for now):
- nvm install 18.17.1
- npm i -g pm2 @metacraft/cli
- curl -sS https://starship.rs/install.sh | sh
