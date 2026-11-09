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

