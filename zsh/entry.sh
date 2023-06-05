export LANG=en_US.UTF-8
export NVM_LAZY_LOAD=true

plugins=(
	git
	zsh-nvm
	zsh-autosuggestions
	zsh-syntax-highlighting
)

alias vim="neovide"
source $ZSH/oh-my-zsh.sh
source ~/nerdtools/zsh/keybindings.sh

export STARSHIP_CONFIG=~/nerdtools/conf/starship.toml
eval "$(starship init zsh)" # load starship theme
