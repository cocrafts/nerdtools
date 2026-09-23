#!/bin/sh
set -u

payload=$(cat)

tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
[ "$tool_name" = "AskUserQuestion" ] || exit 0

questions=$(printf '%s' "$payload" | jq -c '.tool_input.questions // []')
count=$(printf '%s' "$questions" | jq 'length')

if [ "$count" -gt 2 ]; then
  printf 'ask-guard: %s questions in one call; ask at most 2. Lead with the decision that blocks the next step and decide the rest from its answer. Data: ~/nerdtools/claude/playbooks/asking.md\n' "$count" >&2
  exit 2
fi

correction=$(printf '%s' "$questions" | jq -r '
  tostring
  | [match("(…|\\.\\.\\.)\\s*(không|à|ờ)([^[:alpha:]]|$)|,\\s*không,|(^|[^[:alpha:]])(actually|wait)([^[:alpha:]]|$)|ý (tôi|mình) là"; "gi").string]
  | first // empty')
if [ -n "$correction" ]; then
  printf 'ask-guard: an option corrects itself mid-text (%s). Finish the thinking, then write the option as final text.\n' "$correction" >&2
  exit 2
fi

address=$(printf '%s' "$questions" | jq -r '
  tostring
  | gsub("tiếng anh|anh ngữ"; ""; "i")
  | [match("(^|[^[:alpha:][:digit:]])(anh|chị)($|[^[:alpha:][:digit:]])"; "gi").captures[1].string]
  | first // empty')
if [ -n "$address" ]; then
  printf "ask-guard: '%s' assumes the user's gender. Address the user neutrally (in Vietnamese: 'bạn') or drop the pronoun.\n" "$address" >&2
  exit 2
fi

session=$(printf '%s' "$payload" | jq -r '.session_id // "nosession"' | tr -cd 'A-Za-z0-9_-')
seen="${TMPDIR:-/tmp}/ask-guard-$session"
digest=$(printf '%s' "$questions" | cksum | cut -d' ' -f1,2)
if [ -f "$seen" ] && grep -qxF -- "$digest" "$seen"; then
  exit 0
fi
printf '%s\n' "$digest" >>"$seen"

cat >&2 <<'EOF'
ask-guard: before this question reaches the user, check each point, then re-send it unchanged or fixed:
  1. Scope: the decision belongs to the task the user gave. Adjacent work (CI, another repo, the next milestone) is reported, not asked.
  2. Rules: no CLAUDE.md or playbook line already answers it. If one does, act and name the rule.
  3. Evidence: every reference model you cite was read at source in this session (name the file/proc), and the prose above the question gives pros/cons and measured numbers.
  4. Options: each is final text the user can pick without re-reading your reasoning; the recommended one is first.
  5. Commands you hand the user were run by you first.
EOF
exit 2
