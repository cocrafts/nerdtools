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
