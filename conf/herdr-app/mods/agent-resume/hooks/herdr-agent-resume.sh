#!/bin/sh
# Agent hook for the Herdr app mod "agent-resume" (macOS and Linux, POSIX sh).
# The same hook as herdr-agent-resume.ps1. Read that file for the details.
#
# It writes these labels on the herdr-core terminal of the agent:
#   resume.agent, resume.session, resume.pid (the shell pid), resume.args (the flags)
# After a reboot the mod sees a new shell pid and types the resume command.
#
# Usage: sh <this file> <agent> <start|end>
#   Claude Code: SessionStart -> "claude start", SessionEnd -> "claude end"
#   Antigravity: SessionStart -> "agy start"
# Codex has no hook: its hooks run in a shared daemon (see herdr-agent-resume.ps1).

agent="$1"
action="$2"

case "$agent" in
  claude)
    proc='claude'
    script='/@anthropic-ai/claude-code/'
    one_shot_flags=' -p --print '
    one_shot_words=' '
    drop=' --resume -r --continue -c --session-id --fork-session --from-pr '
    values=' --model --permission-mode --effort --agent --settings --add-dir --mcp-config --fallback-model '
    ;;
  agy)
    proc='agy'
    script='/nothing-to-match/'
    one_shot_flags=' -p --print --prompt '
    one_shot_words=' '
    drop=' -c --continue --conversation '
    values=' --model --mode --effort --agent --project --settings --add-dir --log-file '
    ;;
  *) exit 0 ;;
esac

# Only terminals of herdr-core have this variable.
terminal="$HC_TERMINAL_ID"
[ -n "$terminal" ] || exit 0

input=$(cat)

# The value of a JSON string field (no jq needed).
field() {
  printf '%s' "$input" | tr -d '\n' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

session=$(field session_id)
[ -n "$session" ] || session=$(field sessionId)
[ -n "$session" ] || session=$(field conversationId)
case "$session" in
  ''|*[!A-Za-z0-9_-]*) exit 0 ;;
esac

# Sub-agents share the terminal of the main session. Do not record them.
[ -z "$(field agent_id)" ] || exit 0

has() { case "$1" in *" $2 "*) return 0 ;; esac; return 1; }

# The pid of the herdr-core terminal (its shell).
shell_pid=$(hc get "$terminal" --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | tail -n 1)
[ -n "$shell_pid" ] || exit 0

if [ "$action" = end ]; then
  # Claude Code only: remove the labels only when the person exits the agent.
  reason=$(field reason)
  [ "$reason" = prompt_input_exit ] || [ "$reason" = logout ] || exit 0
  current=$(hc get "$terminal" --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"resume\.session"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ "$current" = "$session" ] || exit 0
  hc label "$terminal" resume.agent= resume.session= resume.pid= resume.args= resume.tried= >/dev/null 2>&1
  exit 0
fi

[ "$action" = start ] || exit 0

# Find the agent process above this hook and read its arguments.
pid=$$
args=''
found=''
i=0
while [ "$i" -lt 10 ] && [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  line=$(ps -o args= -p "$pid" 2>/dev/null)
  name=$(ps -o comm= -p "$pid" 2>/dev/null)
  name=${name##*/}
  if [ "$name" = "$proc" ]; then
    args=${line#*"$proc"}
    found=1
    break
  fi
  case "$line" in
    *"$script"*)
      args=${line#*"$script"}
      args=${args#* }
      [ "$args" = "${line#*"$script"}" ] && args=''
      found=1
      break
      ;;
  esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  i=$((i + 1))
done
[ -n "$found" ] || exit 0

# Keep the flags. Drop the session flags, prompt text and unsafe values.
set -f
# shellcheck disable=SC2086
set -- $args
keep=''
first_word=''
while [ $# -gt 0 ]; do
  tok="$1"; shift
  name=${tok%%=*}
  case "$tok" in
    -*)
      if has "$one_shot_flags" "$name"; then exit 0; fi
      if has "$drop" "$name"; then
        case "$tok" in *=*) ;; *) case "$1" in ''|-*) ;; *) shift ;; esac ;; esac
        continue
      fi
      if has "$values" "$tok" && [ $# -gt 0 ]; then
        val="$1"; shift
        case "$val" in *[!A-Za-z0-9_.:/=-]*) ;; *) keep="$keep $tok $val" ;; esac
        continue
      fi
      case "$tok" in *[!A-Za-z0-9_.:/=-]*) ;; *) keep="$keep $tok" ;; esac
      ;;
    *)
      if [ -z "$first_word" ]; then
        first_word="$tok"
        if has "$one_shot_words" "$tok"; then exit 0; fi
      fi
      if has "$drop" "$tok"; then case "$1" in ''|-*) ;; *) shift ;; esac; fi
      ;;
  esac
done
keep=${keep# }

hc label "$terminal" "resume.agent=$agent" "resume.session=$session" "resume.pid=$shell_pid" "resume.args=$keep" resume.tried= >/dev/null 2>&1
exit 0
