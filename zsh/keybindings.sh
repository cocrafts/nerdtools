# up snippet
function up_widget() {
	BUFFER="cd .."
	zle accept-line
}

zle -N up_widget
bindkey "^k" up_widget

# Sudo snippet
function add_sudo() {
	BUFFER="sudo "$BUFFER
	zle end-of-line
}

zle -N add_sudo
bindkey "^s" add_sudo

# Fzf snippet
function fzf_widget() {
	BUFFER=$BUFFER" | fzf"
	zle accept-line
}

zle -N fzf_widget
bindkey "^f" fzf_widget

# Home - Navigates to the current root workspace
function git_root() {
	BUFFER="cd $(git rev-parse --show-toplevel || echo ".")"
	zle accept-line
}
zle -N git_root
bindkey "^l" git_root

