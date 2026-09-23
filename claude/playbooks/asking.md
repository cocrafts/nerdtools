# Asking the user

`CLAUDE.md` "A question earns its place before it is sent" states the rule;
`hooks/ask-guard.sh` enforces its mechanical part. This file keeps the evidence, so the
rule can be re-measured and changed on data instead of feel.

## Baseline, 2026-09-23

`sh scripts/ask-audit.sh 14` over every transcript in `~/.claude/projects` (Windows host,
all repos), before ask-guard existed:

| per call | asked | rejected |
|---|---|---|
| 1 question | 57 | 6 |
| 2 questions | 11 | 2 |
| 4 questions | 4 | 2 |

Prose written since the user's last message: median 891 characters before an answered
question, 444 before a rejected one.

The ten rejections, read by hand with the user's next message:

- 4 asked about work outside the task or ahead of it (CI the user does not touch, the next
  milestone before reviewing the current one, a scope the user then reframed).
- 3 lacked the explanation or the reference reading ("pro và cons và mình đang tham khảo từ
  những mô hình nào rồi - có xem cẩn thận chưa?", "mày hỏi kiểu đáy thì đâu có giải
  thích/visual"). The same miss recurred the day this was measured.
- 2 asked what a rule already answered, or over-built a fix the user wanted retried plainly.
- 1 was interrupted by a peer session.

## What ask-guard does

- More than two questions in one call: blocked every time.
- An option that corrects itself mid-text (`... không,`, `actually`, `wait`): blocked.
- `anh`/`chị` in a question or option (not `tiếng Anh`): blocked; address the user as `bạn`.
- Any other question: blocked once with the five-point checklist, let through when re-sent
  unchanged. The seen set lives in `$TMPDIR/ask-guard-<session>`.

Scope, rule-coverage and reference reading cannot be checked mechanically; the checklist makes
the session look at them once per question.

Proven on the eight real payloads of the `hcr-cross-module` sessions: both four-question
batches, the gendered question and the self-correcting one blocked; the four others blocked
once and passed on re-send; other tools and a `tiếng Anh`/`nhanh`/`cạnh` control untouched.

## Re-measure

Run `sh scripts/ask-audit.sh 14` two weeks after 2026-09-23 and compare with the table
above. The script counts ask-guard stops apart from user rejections. Change the rule when
the rejection rate moves, and record the new numbers here.
