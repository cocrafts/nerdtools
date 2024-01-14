export LANG=en_US.UTF-8
export PATH="$PATH:$HOME/Sources/nvim-macos/bin"
export PATH="$PATH:$HOME/Sources/go/bin"
export PATH="$PATH:$HOME/go/bin"

plugins=(
	git
	zsh-autosuggestions
	zsh-syntax-highlighting
)

alias vide="neovide"
alias nvim="env TERM=wezterm nvim"
source "$ZSH/oh-my-zsh.sh"
source "$HOME/nerdtools/zsh/keybindings.sh"

export STARSHIP_CONFIG=~/nerdtools/conf/starship.toml

eval "$($HOME/.cargo/bin/mise activate zsh)"
eval "$(rbenv init - zsh)"
eval "$(starship init zsh)" # load starship theme
eval "$(zoxide init zsh)"

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
