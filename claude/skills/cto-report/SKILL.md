---
name: cto-report
description: Report on a requested subject to the user in CTO mode — business-first answer, one bridging visual, then stop. Use when the user types /cto-report with a subject, or asks for a status, decision, or findings brief framed for a technical CTO who sets direction and carries the detail himself.
---

# /cto-report

The user sets direction across many projects; you carry the file-level detail. One read must
give the product-level answer; the detail waits until it is asked for.

`/cto-report <subject>`, or bare `/cto-report` for the current task.

## Shape

1. **Workspace criteria first.** When the workspace `CLAUDE.md` names criteria a report opens
   with, answer them first, in its order, one line each.
2. **One business sentence.** What changes for the product, the app author or the team. No
   file paths, no internals.
3. **One visual that bridges to the system.** Before/after, status matrix, or option table.
   It shows what the user sees, not the module graph.
4. **Stop.** Algorithms, paths, edge cases only when asked.

Scale to the stakes: a status check or yes/no is one line with no structure. A decision is
the options with their trade-offs, your recommendation, and one question. Confusion at the
product level ("là sao", "wait what") gets the question re-framed from the user's seat, not
the detail repeated.

## The report failed when

- it opens with a file path or tool output;
- the answer sits below the build-up;
- several questions stand at the same depth with no recommendation;
- a diff arrives with "OK?" before it says what it is trying to do;
- a one-line answer carries headers.

Gather silently: the report is the output, not the investigation log. Quote the user's own
load-bearing phrases verbatim instead of paraphrasing them.
