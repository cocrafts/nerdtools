#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: wt.sh <command> [args]

  new <name> [rev]              create wt/<name>, its linked worktree and card
  card [name|path]              print a worktree card
  ls                            list linked worktrees and their card goals
  rm <name|path> [--force]      retire a worktree after safety checks
  context                       print session context for the current worktree: the
                                handoff at <card root>/handoff/<name>.md if one exists,
                                then the card
  land [name|path] [options]    rebase, gate and fast-forward the main checkout

land options:
  --gate '<command>'            gate to run in the rebased worktree
  --no-gate                     skip the gate only by explicit user decision

env:
  WT_CWD                        repository directory; defaults to CLAUDE_PROJECT_DIR or cwd
  WT_BASE                       main branch; defaults to the main checkout branch
  WT_CARD_ROOT                  card directory; defaults to workspace .wt or main/.cards
  WT_WORKTREE_ROOT              parent directory for linked worktrees
  WT_GATE                       default land gate command

A main-checkout tools/wt.sh is sourced before dispatch. It may redefine cmd_* functions
or define wt_before_*, wt_after_* and wt_context_extra hooks.
USAGE
}

die() { printf 'wt: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*" >&2; }
native_dir() { (cd "$1" && pwd -W 2>/dev/null) || printf '%s\n' "$1"; }

COMMAND=${1:-help}
case "$COMMAND" in
  -h|--help|help) usage; exit 0 ;;
esac

WT_CWD=${WT_CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}
WT_CURRENT=$(git -C "$WT_CWD" rev-parse --show-toplevel 2>/dev/null) || {
  [ "$COMMAND" = context ] && exit 0
  die "not inside a git repository: $WT_CWD"
}
WT_MAIN=$(git -C "$WT_CURRENT" worktree list --porcelain 2>/dev/null | awk 'NR == 1 && /^worktree / { print substr($0, 10); exit }')
[ -n "$WT_MAIN" ] || die "cannot find the main checkout"
WT_BASE=${WT_BASE:-$(git -C "$WT_MAIN" symbolic-ref -q --short HEAD 2>/dev/null)}
[ -n "$WT_BASE" ] || die "main checkout is detached: $WT_MAIN"

wt_workspace_root() {
  local dir=$WT_MAIN parent
  while :; do
    if [ -d "$dir/.wt" ]; then
      printf '%s\n' "$dir"
      return
    fi
    parent=$(dirname "$dir")
    [ "$parent" != "$dir" ] || return 1
    dir=$parent
  done
}

WT_WORKSPACE=${WT_WORKSPACE:-$(wt_workspace_root 2>/dev/null || true)}
if [ -z "${WT_CARD_ROOT:-}" ]; then
  if [ -n "$WT_WORKSPACE" ]; then
    WT_CARD_ROOT=$WT_WORKSPACE/.wt
  else
    WT_CARD_ROOT=$WT_MAIN/.cards
  fi
fi
WT_WORKTREE_ROOT=${WT_WORKTREE_ROOT:-$(dirname "$WT_MAIN")}

wt_slug() { printf '%s' "$1" | tr '/' '-'; }
wt_card_path() { printf '%s/%s.md\n' "$WT_CARD_ROOT" "$(wt_slug "$1")"; }
wt_handoff_path() { printf '%s/handoff/%s.md\n' "$WT_CARD_ROOT" "$(wt_slug "$1")"; }
wt_worktree_path() { printf '%s/%s-wt-%s\n' "$WT_WORKTREE_ROOT" "$(basename "$WT_MAIN")" "$(wt_slug "$1")"; }

wt_branch_name() {
  git -C "$1" symbolic-ref -q --short HEAD 2>/dev/null
}

wt_card_name() {
  local branch
  branch=$(wt_branch_name "$1") || return 1
  case "$branch" in
    wt/*) printf '%s\n' "${branch#wt/}" ;;
    *) return 1 ;;
  esac
}

wt_worktrees() {
  git -C "$WT_MAIN" worktree list --porcelain | awk '/^worktree / { print substr($0, 10) }'
}

wt_find_branch_worktree() {
  local name=$1
  git -C "$WT_MAIN" worktree list --porcelain | awk -v ref="refs/heads/wt/$name" '
    /^worktree / { path = substr($0, 10) }
    /^branch / && substr($0, 8) == ref { print path; exit }
  '
}

wt_resolve() {
  local target=$1 path
  if [ -d "$target" ]; then
    path=$(cd "$target" && pwd -P)
  else
    path=$(wt_find_branch_worktree "$target")
    [ -n "$path" ] || path=$(wt_worktree_path "$target")
  fi
  git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "no worktree at $path"
  printf '%s\n' "$path"
}

wt_seed_card() {
  local name=$1 path
  path=$(wt_card_path "$name")
  [ -e "$path" ] && return 0
  mkdir -p "$WT_CARD_ROOT" || return 1
  printf '# %s\n\nRepo: %s · worktree %s · branch wt/%s\n\n## Goal\n\n## Done when\n\n## State\n' \
    "$name" "$WT_MAIN" "$(wt_worktree_path "$name")" "$name" >"$path"
  say "card: $path"
}

wt_card_goal() {
  awk '/^## / { on = ($0 == "## Goal"); next } on && NF { print; exit }' "$1" 2>/dev/null
}

wt_dirty() {
  git -C "$1" status --porcelain 2>/dev/null
}

wt_unlanded() {
  git -C "$1" rev-list --right-only --cherry-pick --no-merges "$WT_BASE...HEAD" 2>/dev/null
}

wt_processes() {
  local dir=$1
  command -v lsof >/dev/null 2>&1 || return 0
  lsof -nP -d cwd -F pn 2>/dev/null | awk -v d="$dir" '
    /^p/ { pid = substr($0, 2) }
    /^n/ { cwd = substr($0, 2); if (cwd == d || index(cwd, d "/") == 1) print pid }
  ' | sort -u
}

wt_before_new() { :; }
wt_after_new() { :; }
wt_before_rm() { :; }
wt_after_rm() { :; }
wt_before_land() { :; }
wt_after_land() { :; }
wt_context_extra() { :; }

wt_gate() {
  local worktree=$1 gate=$2
  [ -n "$gate" ] || die "land requires --gate '<command>', WT_GATE, or a local wt_gate override"
  say "gate: $gate"
  (cd "$worktree" && bash -c "$gate")
}

cmd_new() {
  local name=${1:-} rev=${2:-$WT_BASE} branch path
  [ -n "$name" ] || die "new: missing <name>"
  branch="wt/$name"
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "new: invalid branch '$branch'"
  path=$(wt_worktree_path "$name")
  wt_before_new "$name" "$rev" "$path" || die "new: local before hook failed"
  if [ -e "$path" ]; then
    [ "$(wt_find_branch_worktree "$name")" = "$path" ] || die "new: $path exists and is not $branch"
    say "reusing $path"
  elif git -C "$WT_MAIN" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$WT_MAIN" worktree add "$path" "$branch" >&2 || die "new: git worktree add failed"
  else
    git -C "$WT_MAIN" worktree add -b "$branch" "$path" "$rev" >&2 || die "new: git worktree add failed"
  fi
  wt_seed_card "$name" || die "new: cannot seed $(wt_card_path "$name")"
  wt_after_new "$name" "$rev" "$path" || die "new: local after hook failed"
  printf '%s\n' "$path"
}

cmd_card() {
  local target=${1:-} path name card
  if [ -n "$target" ] && [ ! -d "$target" ] && [ -f "$(wt_card_path "$target")" ]; then
    name=$target
  else
    path=${target:+$(wt_resolve "$target")}
    path=${path:-$WT_CURRENT}
    name=$(wt_card_name "$path") || die "card: $path is not on a wt/<name> branch"
  fi
  card=$(wt_card_path "$name")
  [ -f "$card" ] || die "card: no card at $card"
  printf '%s\n' "$card"
  cat "$card"
}

wt_context_inbox() {
  local dir count
  [ -n "$WT_WORKSPACE" ] || return 0
  dir=$WT_WORKSPACE/.inbox/$(basename "$WT_MAIN")
  [ -d "$dir" ] || return 0
  count=$(find "$dir" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] || return 0
  printf '%s note(s) in %s — read them before other work\n' "$count" "$dir"
}

wt_context_handoff() {
  local name handoff
  name=$(wt_card_name "$WT_CURRENT") || return 0
  handoff=$(wt_handoff_path "$name")
  [ -f "$handoff" ] || return 0
  printf 'Handoff from the previous session, %s, written %s. Read it before the card and check the local state it names. Delete it once your first step is under way. Where it disagrees with the card, the card wins.\n' \
    "$handoff" "$(date -r "$handoff" '+%Y-%m-%d %H:%M' 2>/dev/null || printf 'at an unknown time')"
  cat "$handoff"
  printf '\n'
}

cmd_context() {
  local name card
  if name=$(wt_card_name "$WT_CURRENT"); then
    card=$(wt_card_path "$name")
    if [ -f "$card" ]; then
      printf 'Card of this worktree, %s:\n' "$card"
      cat "$card"
    else
      printf 'This worktree is on wt/%s and has no card at %s. Write Goal, Done when, and State before the first commit.\n' "$name" "$card"
    fi
  fi
  wt_context_inbox
  wt_context_extra "$WT_CURRENT"
}

cmd_ls() {
  local path branch dirty ahead name card goal
  printf '%-7s %-5s %-40s %s\n' DIRTY AHEAD BRANCH PATH
  while IFS= read -r path; do
    [ "$path" != "$WT_MAIN" ] || continue
    branch=$(wt_branch_name "$path" || printf 'detached')
    dirty=$(wt_dirty "$path" | wc -l | tr -d ' ')
    ahead=$(wt_unlanded "$path" | wc -l | tr -d ' ')
    goal=""
    if name=$(wt_card_name "$path"); then
      card=$(wt_card_path "$name")
      goal=$(wt_card_goal "$card")
    fi
    printf '%-7s %-5s %-40s %s' "$dirty" "$ahead" "$branch" "$path"
    [ -z "$goal" ] || printf ' · %s' "$goal"
    printf '\n'
  done < <(wt_worktrees)
}

cmd_rm() {
  local target="" force=0 arg path dirty unlanded processes branch
  for arg in "$@"; do
    case "$arg" in
      --force) force=1 ;;
      *) target=$arg ;;
    esac
  done
  [ -n "$target" ] || die "rm: missing <name|path>"
  path=$(wt_resolve "$target")
  [ "$path" != "$WT_MAIN" ] || die "rm: refusing to remove the main checkout"
  branch=$(wt_branch_name "$path" || true)
  dirty=$(wt_dirty "$path")
  unlanded=$(wt_unlanded "$path")
  processes=$(wt_processes "$path")
  wt_before_rm "$path" "$branch" || die "rm: local before hook failed"
  if [ "$force" -eq 0 ]; then
    [ -z "$dirty" ] || die "rm: uncommitted files remain in $path"
    [ -z "$unlanded" ] || die "rm: commits not on $WT_BASE remain in $path"
    [ -z "$processes" ] || die "rm: live processes remain in $path: $(printf '%s' "$processes" | tr '\n' ' ')"
  fi
  if [ "$force" -eq 1 ]; then
    git -C "$WT_MAIN" worktree remove --force "$path" || die "rm: git refused"
  else
    git -C "$WT_MAIN" worktree remove "$path" || die "rm: git refused"
  fi
  case "$branch" in
    wt/*)
      if [ "$force" -eq 1 ]; then
        git -C "$WT_MAIN" branch -D "$branch" >/dev/null || die "rm: cannot delete $branch"
      else
        git -C "$WT_MAIN" branch -d "$branch" >/dev/null || die "rm: cannot delete $branch"
      fi
      ;;
  esac
  wt_after_rm "$path" "$branch" || die "rm: local after hook failed"
  say "removed $path"
}

cmd_land() {
  local target="" gate=${WT_GATE:-} no_gate=0 path branch old new arg
  while [ $# -gt 0 ]; do
    arg=$1
    case "$arg" in
      --gate)
        shift
        [ $# -gt 0 ] || die "land: --gate needs a command"
        gate=$1
        ;;
      --no-gate) no_gate=1 ;;
      *) target=$arg ;;
    esac
    shift
  done
  path=${target:+$(wt_resolve "$target")}
  path=${path:-$WT_CURRENT}
  [ "$path" != "$WT_MAIN" ] || die "land: run from a linked worktree"
  branch=$(wt_branch_name "$path") || die "land: detached worktree"
  case "$branch" in wt/*) ;; *) die "land: branch must be wt/<name>" ;; esac
  [ -z "$(wt_dirty "$path")" ] || die "land: $path has uncommitted files"
  old=$(git -C "$WT_MAIN" rev-parse "$WT_BASE") || die "land: cannot resolve $WT_BASE"
  git -C "$path" rebase "$old" || {
    git -C "$path" rebase --abort >/dev/null 2>&1 || true
    die "land: rebase onto $WT_BASE failed"
  }
  new=$(git -C "$path" rev-parse HEAD)
  [ "$new" != "$old" ] || die "land: nothing to land"
  wt_before_land "$path" "$old" "$new" || die "land: local before hook failed"
  if [ "$no_gate" -eq 1 ]; then
    say "land: --no-gate"
  else
    wt_gate "$path" "$gate" || die "land: gate failed"
  fi
  [ "$(git -C "$WT_MAIN" rev-parse "$WT_BASE")" = "$old" ] || die "land: $WT_BASE moved during the gate; run land again"
  git -C "$WT_MAIN" merge --ff-only "$new" || die "land: main checkout refused the fast-forward"
  wt_after_land "$path" "$old" "$new" || die "land: local after hook failed"
  say "landed $branch at $(git -C "$WT_MAIN" rev-parse --short "$new")"
}
wt_hook_field() {
  jq -r --arg key "$1" '.[$key] // empty'
}

cmd_hook_create() {
  local name w
  name=$(wt_hook_field name)
  [ -n "$name" ] || die "hook-create: input has no name"
  w=$(cmd_new "$name") && native_dir "$w"
}

cmd_hook_remove() {
  local path
  path=$(wt_hook_field worktree_path)
  [ -n "$path" ] || die "hook-remove: input has no worktree_path"
  cmd_rm "$path"
}


WT_ADAPTER=$WT_MAIN/tools/wt.sh
if [ -f "$WT_ADAPTER" ] && [ "$(cd "$(dirname "$WT_ADAPTER")" && pwd -P)/$(basename "$WT_ADAPTER")" != "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" ]; then
  export WT_SHARED_TOOL=$0
  export WT_ADAPTER_ACTIVE=1
  # shellcheck disable=SC1090
  source "$WT_ADAPTER"
fi

shift
case "$COMMAND" in
  new) cmd_new "$@" ;;
  card) cmd_card "$@" ;;
  ls) cmd_ls "$@" ;;
  rm) cmd_rm "$@" ;;
  context) wt_context_handoff; cmd_context "$@" ;;
  land) cmd_land "$@" ;;
  hook-create) cmd_hook_create ;;
  hook-remove) cmd_hook_remove ;;
  __ls_row) ls_row "${1%%$'\t'*}" "${1#*$'\t'}" ;;
  *) usage >&2; exit 2 ;;
esac
