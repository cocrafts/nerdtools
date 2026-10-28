#!/bin/sh
set -u

payload=$(cat)
[ "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0
case $(printf '%s' "$payload" | jq -r '.cwd // empty') in
  "$HOME"/metascript|"$HOME"/metascript/*) ;;
  *) exit 0 ;;
esac
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')

case $cmd in
  *MAC_ONLY=1*|*run-remote.sh*|*"ssh "*|*pick-host.sh*|*"wt.sh land"*|*"tools/gate.sh --dry-run"*) exit 0 ;;
esac

heavy=""
case $cmd in
  *"build src/index.ms"*|*"build ./src/index.ms"*) heavy="a compiler candidate build" ;;
  *--tests-in-dir*) heavy="a --tests-in-dir run" ;;
  *corpus/run.ms*) heavy="a corpus run" ;;
  *guard/run.ms*) heavy="a guard run" ;;
  *tools/gate.sh*) heavy="a gate" ;;
esac
[ -n "$heavy" ] || exit 0

cat >&2 <<EOF
heavy-on-mac-guard: this is $heavy, a heavy job, and the Mac is shared with the land queue and every session's
edit loop (~/metascript/CLAUDE.md, "Run pick-host before every heavy job"). Run it on a gate host instead:
  ~/metascript/.gate-host/run-remote.sh --cores N --ram G --job "<session>: <what>" -- <the same command>
from inside the worktree; it reserves the host, copies the tree, runs the command and returns its exit code.
If the job needs macOS (lines only macOS compiles, Haro, Ion, the Neon gate), prefix the command with MAC_ONLY=1.
EOF
exit 2
