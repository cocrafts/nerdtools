#!/bin/sh
set -u

payload=$(cat)

file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
[ -n "$file_path" ] || exit 0

tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
[ "$tool_name" = "Edit" ] || [ "$tool_name" = "Write" ] || exit 0

ext=${file_path##*.}
ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

case "$ext" in
  ms|ts|tsx|js|jsx|mjs|cjs|c|h|cpp|hpp|cc|hh|cxx|rs|go|java|kt|kts|swift|zig|cs|css|scss|dart|groovy)
    line_comment='^[[:space:]]*(//|/\*)' ;;
  py|pyw|sh|bash|zsh|rb|yaml|yml|toml|ini|conf|cfg|r|pl)
    line_comment='^[[:space:]]*#' ;;
  sql|lua|hs|elm)
    line_comment='^[[:space:]]*--' ;;
  *)
    exit 0 ;;
esac

case "$tool_name" in
  Edit)
    new_text=$(printf '%s' "$payload" | jq -r '.tool_input.new_string // empty')
    old_text=$(printf '%s' "$payload" | jq -r '.tool_input.old_string // empty') ;;
  Write)
    response=$(printf '%s' "$payload" | jq -r '(.tool_response // "") | tostring')
    case "$response" in
      *reated*) ;;
      *) exit 0 ;;
    esac
    new_text=$(printf '%s' "$payload" | jq -r '.tool_input.content // empty')
    old_text='' ;;
esac

[ -n "$new_text" ] || exit 0

candidates=$(printf '%s\n' "$new_text" | grep -E "$line_comment" | grep -Ev '^[[:space:]]*#!' || true)
[ -n "$candidates" ] || exit 0

added=''
while IFS= read -r line; do
  if printf '%s\n' "$old_text" | grep -qxF -- "$line"; then
    continue
  fi
  added="$added$line
"
done <<EOF
$candidates
EOF

[ -n "$added" ] || exit 0

{
  printf 'comment-guard: added comment lines in %s\n' "$file_path"
  printf '%s\n' "$added" | head -n 8 | sed 's/^/  /'
  printf 'delete them, or keep only what passes the three-part test in ~/nerdtools/claude/playbooks/comment.md: not derivable from the code, not encodable as a name/test/assertion, load-bearing for a future edit\n'
} >&2
exit 2
