#!/bin/bash

DEFAULT_MODEL="Opus 5"

input=$(cat)

{
  read -r tokens; read -r pct; read -r model; read -r dir
  read -r five; read -r five_at; read -r week; read -r week_at
  read -r effort
} < <(
  printf '%s' "$input" | jq -r '
    (.context_window.total_input_tokens // 0),
    (.context_window.used_percentage // 0),
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // ""),
    (.effort.level // "")' | tr -d '\r'
)

case "$effort" in
  low)    ecolor=$'\033[90m' ;;
  medium) ecolor=$'\033[94m' ;;
  high)   ecolor=$'\033[92m' ;;
  xhigh)  ecolor=$'\033[93m' ;;
  max)    ecolor=$'\033[91m' ;;
  ultracode) ecolor=$'\033[95m' ;;
  *)      ecolor='' ;;
esac
ereset=''
[ -n "$ecolor" ] && ereset=$'\033[0m'

case "$model" in
  "$DEFAULT_MODEL"|"$DEFAULT_MODEL "*) model='' ;;
  *) model="$ecolor$model$ereset · " ;;
esac

[ -n "$dir" ] || dir="$PWD"
folder=$(basename "$dir")

ctx=$(awk -v t="$tokens" 'BEGIN{
  if (t >= 1000000) printf "%.1fM", t/1000000;
  else if (t >= 1000) printf "%.1fK", t/1000;
  else printf "%d", t;
}')

now=$(date +%s)

quota_segment() {
  local label=$1 raw_pct=$2 raw_at=$3
  [ -n "$raw_pct" ] || return 0

  local p color='' reset=''
  p=$(printf '%.0f' "$raw_pct")
  if [ "$p" -ge 90 ]; then
    color=$'\033[31m'; reset=$'\033[0m'
  elif [ "$p" -ge 70 ]; then
    color=$'\033[33m'; reset=$'\033[0m'
  fi

  local countdown=''
  if [ -n "$raw_at" ]; then
    local at
    at=$(printf '%.0f' "$raw_at")
    [ "$at" -gt "$now" ] && countdown=$(awk -v s=$((at - now)) 'BEGIN{
      d = int(s/86400); h = int(s%86400/3600); m = int(s%3600/60);
      if (d > 0) printf "\033[2m→%dd%dh\033[22m", d, h;
      else if (h > 0) printf "\033[2m-%dh%dm\033[22m", h, m;
      else if (m > 0) printf "\033[2m-%dm\033[22m", m;
      else printf "\033[2m-<1m\033[22m";
    }')
  fi

  [ -n "$countdown" ] && label=''
  printf ' · %s%s%d%%%s%s' "$color" "$label" "$p" "$reset" "$countdown"
}

quota="$(quota_segment "5h " "$five" "$five_at")$(quota_segment "7d " "$week" "$week_at")"

account=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
[ -n "$account" ] && account=" · $account"

printf '%s%s%s (%s%%)%s · %s%s%s' "$model" "$ecolor" "$ctx" "$pct" "$ereset" "$folder" "$quota" "$account"
