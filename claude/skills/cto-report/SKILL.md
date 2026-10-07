---
name: cto-report
description: Report on a requested subject in CTO mode — product-level answer first, evidence and recommendation as needed. Use for an explicit /cto-report request or a product-level status, decision, or findings brief, not ordinary technical questions or progress replies.
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
3. **A visual only when useful.** A small before/after, status matrix or option table can
   clarify an app-visible difference; omit it when prose already says it clearly.
4. **Stop at the next action or decision.** Keep necessary evidence; leave algorithm walkthroughs
   and unrelated edge cases for a follow-up, so the brief stays focused on the user's call.

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
