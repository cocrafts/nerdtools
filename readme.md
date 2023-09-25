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
- brew install jq
- brew install llvm --with-toolchain (clang, clang-tidy, clang-format)
- cargo install typos-cli or brew install typos-cli (typos)
- cargo install neocmakelsp (for .cmake)
- cargo install selene (lua linter, lighting fast)
- cargo install --features lsp --locked taplo-cli (for toml)
- npm install -g eslint_d
- npm install -g write-good
- npm i -g bash-language-server

### Other notes:
- For Kitty, while ssh to Linux client with Nerdtools use `kitty +kitten ssh` instead of `ssh` once to register Kitty with remote system.
- For Wezterm [Configure undercurl](https://wezfurlong.org/wezterm/faq.html?h=undercurl#how-do-i-enable-undercurl-curly-underlines) style for Wezterm.
