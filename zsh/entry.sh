export LANG=en_US.UTF-8
export NVM_LAZY_LOAD=true

plugins=(
	git
	zsh-nvm
	zsh-autosuggestions
	zsh-syntax-highlighting
)

alias vide="neovide"
alias nvim="env TERM=wezterm nvim"
source $ZSH/oh-my-zsh.sh
source ~/nerdtools/zsh/keybindings.sh

export STARSHIP_CONFIG=~/nerdtools/conf/starship.toml
eval "$(rbenv init - zsh)"
eval "$(starship init zsh)" # load starship theme
eval "$(zoxide init zsh)"
