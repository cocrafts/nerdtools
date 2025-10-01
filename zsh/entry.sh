export LANG=en_US.UTF-8
export ZSH="$HOME/.oh-my-zsh"

export PATH="$HOME/Sources/neovim/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/Sources/bin"
export PATH="$PATH:$HOME/Sources/haxe/bin"
export PATH="$PATH:$HOME/go/bin"
export PATH="$PATH:$HOME/nerdtools/bin"

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export XDG_CONFIG_HOME="$HOME/.config"

plugins=(
	git
	copyfile
	jsontools
	zsh-autosuggestions
	zsh-syntax-highlighting
)

alias vide="neovide"
alias nvim="env TERM=wezterm nvim"
source "$ZSH/oh-my-zsh.sh"
source "$HOME/nerdtools/zsh/keybindings.sh"

export STARSHIP_CONFIG=~/nerdtools/conf/starship.toml
export REACT_EDITOR=nvim

eval "$($HOME/.cargo/bin/mise activate zsh)"
eval "$(starship init zsh)" # load starship theme
eval "$(zoxide init zsh)"

# Exclude common command from Zsh command history
HISTORY_IGNORE="(clear|ls|cd|pwd|exit|history)"
zshaddhistory() {
  emulate -L zsh
  [[ $1 != ${~HISTORY_IGNORE} ]]
}

# Dynamically include llvm would execute instantly, took ~0 millisecond!
llvm_dir="/usr/local/Cellar/llvm/"
llvm_latest_version=""

if [[ -d "$llvm_dir" ]]; then
	for dir in "$llvm_dir"*/; do
		version="${dir%/}" # Remove trailing slash
		if [[ -d "$version" && ! -L "$version" ]]; then
			if [[ -z "$llvm_latest_version" || "$version" > "$llvm_latest_version" ]]; then
				llvm_latest_version="$version"
			fi
		fi
	done

	if [[ -n "$llvm_latest_version" ]]; then
		export PATH="$PATH:$llvm_latest_version/bin"
	fi
fi
