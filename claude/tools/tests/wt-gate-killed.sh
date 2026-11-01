#!/usr/bin/env bash
set -euo pipefail

wt_sh=$(cd "$(dirname "$0")/.." && pwd)/wt.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main main
git -C main commit -q --allow-empty -m init
git -C main worktree add -q ../wt -b wt/x
git -C wt commit -q --allow-empty -m work
base=$(git -C main rev-parse main)
land() { WT_CWD="$tmp/wt" WT_CARD_ROOT="$tmp/cards" bash "$wt_sh" land --gate "$1" >/dev/null 2>&1; }

# exec ends the gate shell with status 0 before its last step, as a taskkill'd child reads in Git Bash.
if land 'exec true'; then echo "FAIL: a gate that exited 0 before its end landed"; exit 1; fi
[ "$(git -C main rev-parse main)" = "$base" ] || { echo "FAIL: main moved on an unfinished gate"; exit 1; }

land true || { echo "FAIL: a green gate did not land"; exit 1; }
[ "$(git -C main rev-parse main)" = "$(git -C wt rev-parse HEAD)" ] || { echo "FAIL: main is not at the landed tip"; exit 1; }
echo "PASS wt-gate-killed: only a gate that reaches its end lands"
