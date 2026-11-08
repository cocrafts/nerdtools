---
name: cto-report
description: Report on a requested subject in CTO mode — product-level answer first, evidence and recommendation as needed. Use for an explicit /cto-report request, a product-level status, decision or findings brief, and the stop report that ends any turn leaving approved work done, in flight or blocked; not for a turn that only answers a question.
---

# /cto-report

The user sets direction across many projects; you carry the file-level detail. One read must
give the product-level answer; the detail waits until it is asked for.

`/cto-report <subject>`, or bare `/cto-report` for the current task.

## Shape

1. **Answer first.** Say what changes for the product, the app author or the team, without
   making the user read a checklist or internals to find the conclusion.
2. **Enough evidence to judge it.** Include the proof, trade-off and recommendation relevant
   to the request. Follow workspace criteria where they apply, without turning them into
   repeated labels; reference anchors support the answer rather than precede it.
3. **A visual only when useful.** In a brief the user asked for, a small before/after, status
   matrix or option table can clarify an app-visible difference; a stop report carries none,
   because it is read in passing between sessions.
4. **Stop at the next action or decision.** Keep necessary evidence; leave algorithm walkthroughs
   and unrelated edge cases for a follow-up, so the brief stays focused on the user's call.

Scale to the stakes: a status check or yes/no is one line with no structure. A decision is
the options with each one's concrete cost and risk, your recommendation, what you do while
waiting, and one question. Confusion at the
product level ("là sao", "wait what") gets the question re-framed from the user's seat, not
the detail repeated.

## Stop report

The stop report that ends a turn is written as global `CLAUDE.md` §Reporting says, because every
turn reads that text and only some load this skill.

Gather silently: the report is the output, not the investigation log. Quote the user's own
load-bearing phrases verbatim, because their own words are what they recognize at a glance.
