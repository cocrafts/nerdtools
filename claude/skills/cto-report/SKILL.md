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
3. **A visual only when useful.** A small before/after, status matrix or option table can
   clarify an app-visible difference; omit it when prose already says it clearly.
4. **Stop at the next action or decision.** Keep necessary evidence; leave algorithm walkthroughs
   and unrelated edge cases for a follow-up, so the brief stays focused on the user's call.

Scale to the stakes: a status check or yes/no is one line with no structure. A decision is
the options with each one's concrete cost and risk, your recommendation, what you do while
waiting, and one question. Confusion at the
product level ("là sao", "wait what") gets the question re-framed from the user's seat, not
the detail repeated.

## Stop report

Every turn that leaves approved work done, in flight or blocked ends with one, at most about 150
words with one sentence per line, because the user reads it cold, between many sessions. Detail
lives in the card, the commits or a follow-up the user asks for, not here.

1. **State line**, first: **DONE**, **WAITING**, **NEEDS YOU** or **BLOCKED**, named by who acts
   next, and the one fact that matters: the result with its number; what it waits on and when it
   resumes by itself; the decision; the blocker and who was told.
2. **Context line**: the arc's goal in plain words and where this stop sits in it (done, next,
   left), so a reader arriving from another session knows what this is. A name the reader needs (a
   host, a card, a term this session coined) is glossed where it appears or dropped.
3. **What the state needs, nothing more.** NEEDS YOU: each option in one sentence with its cost, the
   recommendation, what continues meanwhile; one minimal example only when it decides the choice.
   Several states or decisions: one line each, NEEDS YOU first and the weightiest decision first;
   each waiting decision is restated in one line until answered.
4. **Solid**, **Backed by**, **Covers**, **Leaves**: one line each, only when the result cannot speak
   for itself (compiler or other subtle logic, above all against a reference; a claim others build
   on). Backed by may read "workaround, root fix is X, pivot?". Covers is the class of cases a chosen
   fix or design fixes, Leaves the sibling cases it does not and why, because a narrow fix must
   show here, not in a later question.
5. **The git line** the global reporting rule asks for, last.

A turn that changes nothing says so in one line.

## The report failed when

- it opens with a file path or tool output;
- the answer sits below the build-up;
- several questions stand at the same depth with no recommendation;
- a diff arrives with "OK?" before it says what it is trying to do;
- a one-line answer carries headers;
- a turn that leaves work done, in flight or blocked ends without the stop report;
- the state is not the first line, or the stop report carries headers, tables or the investigation.

Gather silently: the report is the output, not the investigation log. Quote the user's own
load-bearing phrases verbatim instead of paraphrasing them.
