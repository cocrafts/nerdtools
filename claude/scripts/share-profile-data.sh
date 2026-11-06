#!/bin/bash
# Make the Claude Code profiles ~/.claude-1..6 (aliases cl1..cl6) share the default profile's session data:
# projects/ (transcripts for /resume, per-project memory), file-history/, sessions/ (the live-session registry that
# ListAgents and SendMessage read) and history.jsonl become links into
# ~/.claude, so `claude`, cl1..cl6 and pi see one store and can message each other. Login (.claude.json, Keychain) and plugins/
# stay per profile.
#
# The default profile never goes quiet (pi and its sessions keep writing), so this only ADDS files to it: a profile
# file whose path is free moves in, an identical one is dropped, a different one moves in beside it as <name>.clN.
# history.jsonl is not merged (live sessions append to it); each profile's old one stays in the backup.
#
#   share-profile-data.sh --dry-run   show what would move and which files collide
#   share-profile-data.sh             do it (refuses while a cl1..cl6 session runs; backs up first)
set -euo pipefail

SHARED=$(cd "$HOME/.claude" && pwd -P)
PROFILES=("$HOME/.claude-1" "$HOME/.claude-2" "$HOME/.claude-3" "$HOME/.claude-4" "$HOME/.claude-5" "$HOME/.claude-6")
DIRS=(projects file-history sessions)
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

run() { if [ $DRY -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }

busy=()
for pid in $(pgrep -x claude || true); do
	dir=$(ps -E -o command= -p "$pid" 2>/dev/null | /usr/bin/grep -o "CLAUDE_CONFIG_DIR=[^ ]*" | cut -d= -f2 || true)
	for p in "${PROFILES[@]}"; do [ "$dir" = "$p" ] && busy+=("$pid ($(basename "$p"))"); done
done
if [ ${#busy[@]} -gt 0 ]; then
	echo "${#busy[@]} session(s) still run on cl1..cl6: ${busy[*]}"
	[ $DRY -eq 0 ] && { echo "refused: close them first (plain \`claude\` and pi may keep running)" >&2; exit 1; }
fi

backup="$HOME/.claude-share-backup-$(date +%Y%m%d-%H%M%S)"
if [ $DRY -eq 0 ]; then
	echo "backup → $backup"
	for p in "${PROFILES[@]}"; do
		n=$(basename "$p")
		mkdir -p "$backup/$n"
		for item in "${DIRS[@]}" history.jsonl; do
			if [ -e "$p/$item" ] && [ ! -L "$p/$item" ]; then cp -a "$p/$item" "$backup/$n/"; fi
		done
	done
fi

conflicts=()
for p in "${PROFILES[@]}"; do
	n=$(basename "$p")
	tag=${n#.claude-}
	for item in "${DIRS[@]}" history.jsonl; do
		src="$p/$item"
		if [ -L "$src" ]; then echo "$n/$item already linked"; continue; fi
		if [ -d "$src" ]; then
			while IFS= read -r -d '' f; do
				rel=${f#"$src"/}
				dst="$SHARED/$item/$rel"
				if [ ! -e "$dst" ]; then
					run mkdir -p "$(dirname "$dst")"
					run mv "$f" "$dst"
				elif ! cmp -s "$f" "$dst"; then
					base=${dst%.*}; ext=${dst##*.}
					if [ "$base" = "$dst" ] || [[ "$ext" == */* ]]; then alt="$dst.cl$tag"; else alt="$base.cl$tag.$ext"; fi
					conflicts+=("$alt")
					run mv "$f" "$alt"
				fi
			done < <(find "$src" -type f -print0)
		fi
		run rm -rf "$src"
		run ln -s "$SHARED/$item" "$src"
	done
done

if [ ${#conflicts[@]} -gt 0 ]; then
	echo "kept both copies of ${#conflicts[@]} file(s) that differed; merge each .clN copy into its original by hand:"
	printf '  %s\n' "${conflicts[@]}"
fi
if [ $DRY -eq 0 ]; then echo "done; backup at $backup"; fi
