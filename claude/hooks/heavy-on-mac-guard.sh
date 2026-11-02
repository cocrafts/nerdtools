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
  *MAC_ONLY=1*|*run-remote.sh*|*"ssh "*|*pick-host.sh*|*"tools/gate.sh --dry-run"*) exit 0 ;;
esac

heavy=""
case $cmd in
  *"wt.sh land"*--gate*) heavy="a land gate run here" ;;
  *"wt.sh land"*) exit 0 ;;
esac

[ -n "$heavy" ] || case $cmd in
  *"msc build src/index.ms"*|*"msc build ./src/index.ms"*) heavy="a compiler candidate build" ;;
  *"msc test "*--tests-in-dir*) heavy="a --tests-in-dir run" ;;
  "msc test "*|"./msc test "*|*"&& msc test "*|*"&& ./msc test "*|*"; msc test "*|*"; ./msc test "*) heavy="a test run" ;;
  *"msc run src/test/perf/run.ms"*|*"msc run src/test/fmt/run.ms"*|*"msc run src/test/lsp/run.ms"*) heavy="a test runner" ;;
  *"run src/test/corpus/run.ms"*|*"run ./src/test/corpus/run.ms"*) heavy="a corpus run" ;;
  *"src/test/guard/run.ms"*) case $cmd in *"msc run"*) heavy="a guard run" ;; esac ;;
  "tools/gate.sh"*|"./tools/gate.sh"*|*"&& tools/gate.sh"*|*"; tools/gate.sh"*|*"bash tools/gate.sh"*) heavy="a gate" ;;
esac
[ -n "$heavy" ] || ! printf '%s' "$cmd" | grep -qE '(^|[;&|] *|bash |sh |node )(\./)?(tests/run\.sh|scripts/gate\.sh|tests/samples\.mjs)' \
  || heavy="a repo test runner"
[ -n "$heavy" ] || exit 0

cat >&2 <<EOF
heavy-on-mac-guard: this is $heavy, a heavy job, and the Mac is shared with the land queue and every session's
edit loop (~/metascript/CLAUDE.md §Shared machines). Run it on a gate host instead:
  ~/metascript/.gate-host/run-remote.sh --cores N --job "<session>: <what>" -- <the same command>
from inside the worktree; it reserves the host, copies the tree, runs the command and returns its exit code.
A run whose every test needs macOS (lines only macOS compiles, a window, GPU or pty on macOS, a darwin budget) goes through
run-remote.sh --mac, which takes a remote Mac first and this Mac only while none is free; a land gate splits its Mac-only
tests there and everything else through run-remote.sh. Prefix MAC_ONLY=1 here only to a run that needs this Mac's own
screen session or attached devices, because the person works on this Mac (§Shared machines).
EOF
exit 2
