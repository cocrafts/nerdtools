#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values with safe defaults
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# Get context indicator based on exceeds_200k_tokens flag
exceeds_limit=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
if [ "$exceeds_limit" = "true" ]; then
    context_indicator="⚠"
else
    context_indicator="✓"
fi


# Get current directory basename
if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
    dir_name=$(basename "$current_dir")
else
    dir_name=$(basename "$(pwd)")
    current_dir="$(pwd)"
fi

# Check if we're in a git repository
if [ -d "$current_dir/.git" ]; then
    cd "$current_dir" 2>/dev/null
    git_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    printf "\033[1;32m$(whoami)\033[0m \033[1;34m%s\033[0m \033[1;90mon\033[0m \033[1;35m%s\033[0m \033[1;90mwith\033[0m \033[1;36m%s\033[0m \033[1;32m%s\033[0m" "$dir_name" "$git_branch" "$model_name" "$context_indicator"
else
    printf "\033[1;32m$(whoami)\033[0m \033[1;34m%s\033[0m \033[1;90mwith\033[0m \033[1;36m%s\033[0m \033[1;32m%s\033[0m" "$dir_name" "$model_name" "$context_indicator"
fi