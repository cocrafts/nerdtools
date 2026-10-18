#!/usr/bin/env bash
set -euo pipefail

wt_sh=$(cd "$(dirname "$0")/.." && pwd)/wt.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
mkdir target && echo keep > target/file.txt
git init -q main
git -C main commit -q --allow-empty -m init
echo deps/ > main/.gitignore
git -C main add .gitignore && git -C main commit -qm ignore
git -C main worktree add -q ../wt -b wt/x
if command -v cygpath >/dev/null; then
  MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$tmp/wt/deps")" "$(cygpath -w "$tmp/target")" >/dev/null
else
  ln -s "$tmp/target" wt/deps
fi

WT_CWD="$tmp/main" WT_CARD_ROOT="$tmp/cards" bash "$wt_sh" rm "$tmp/wt"

[ ! -e wt ] || { echo "FAIL: worktree still exists"; exit 1; }
[ "$(cat target/file.txt)" = keep ] || { echo "FAIL: rm emptied the target of a link inside the worktree"; exit 1; }
echo "PASS wt-rm-links: rm leaves the target of a directory link in place"
