#!/usr/bin/env bash
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_PANE_ID:?split.sh: HERDR_PANE_ID is unset; run it as a herdr plugin action}"

case "${1:?usage: split.sh <left|up>}" in
  left) split=right ;;
  up) split=down ;;
  *) echo "split.sh: unknown direction: $1" >&2; exit 2 ;;
esac

new=$("$herdr" pane split --pane "$pane" --direction "$split" --focus | jq -er '.result.pane.pane_id')
"$herdr" pane swap --source-pane "$new" --target-pane "$pane"
