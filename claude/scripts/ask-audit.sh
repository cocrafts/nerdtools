#!/bin/sh
set -eu

days=${1:-14}
root=$HOME/.claude/projects

find "$root" -name '*.jsonl' -mtime "-$days" | while IFS= read -r file; do
  jq -R -c 'fromjson? | select(.isSidechain | not) | .message // empty' "$file" |
    jq -n -c '
      reduce inputs as $m ({pending: {}, since: 0, out: []};
        if $m.role == "user" and ($m.content | type) == "string" then
          .since = 0
        elif $m.role == "assistant" and ($m.content | type) == "array" then
          .since += ([$m.content[] | select(.type == "text") | .text | length] | add // 0)
          | reduce ($m.content[] | select(.type == "tool_use" and .name == "AskUserQuestion")) as $t (.;
              .pending[$t.id] = {n: ($t.input.questions | length), before: .since})
        elif $m.role == "user" and ($m.content | type) == "array" then
          reduce ($m.content[] | select(type == "object" and .type == "tool_result")) as $r (.;
            if .pending[$r.tool_use_id] then
              .pending[$r.tool_use_id] as $p
              | ($r.content | tojson) as $s
              | .out += [{n: $p.n, before: $p.before,
                          blocked: ($s | contains("ask-guard:")),
                          refused: ($s | contains("want to proceed"))}]
              | del(.pending[$r.tool_use_id])
            else . end)
        else . end)
      | .out[]'
done | jq -s -r --arg days "$days" '
  def median: sort | if length == 0 then "-" else .[length / 2 | floor] end;
  (map(select(.blocked | not))) as $reached
  | "last \($days) days: \($reached | length) questions reached the user, \($reached | map(select(.refused)) | length) rejected; \(map(select(.blocked)) | length) stopped by ask-guard",
    ($reached | group_by(.n)[] | "  \(.[0].n) per call: \(length) asked, \(map(select(.refused)) | length) rejected"),
    "  prose before an answered question: median \($reached | map(select(.refused | not) | .before) | median) chars",
    "  prose before a rejected question: median \($reached | map(select(.refused) | .before) | median) chars"'
