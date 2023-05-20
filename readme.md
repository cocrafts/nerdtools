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

### Other notes:
- For Kitty user, while ssh to Linux client with Nerdtools use `kitty +kitten ssh` instead of `ssh` once to register Kitty with remote system.
