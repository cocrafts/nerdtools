---
name: get-back
description: Re-orient the user after they lose context, and audit the work in flight against the house discipline. Answers "what did we just finish, where are we, and are we still extending the existing design instead of inventing new mechanisms?" Use when the user types /get-back, or says they lost context and wants to know both the state and whether the rules are still being held.
---

# get-back — báo cáo lại vị trí + tự soi kỷ luật

The user has lost the thread and wants two things at once, in this order:

1. **Where are we** — what just completed, what is in flight, what is pending.
2. **Are we still honest** — did the work extend the existing design, or did it
   quietly invent a new mechanism, a new flow, a new concept?

Job 2 is the one he actually worries about. A recap that says "all green" and
skips the discipline audit has failed this skill.

## Hard rules

- **Evidence, not recall.** Every state claim comes from something you can show
  this session: a gate log, a command's real output, a diff. "The suite passed"
  is worthless; `Tests 3687 passed (3687)` is the claim. If the only source is
  your memory of an earlier turn, say so explicitly, or re-run it.
- **Never launder a stale number.** A gate that ran before the last edit does not
  describe the current tree. Say which binary and which commit produced each
  number.
- **The audit names mechanisms, not intentions.** For every piece of work, name
  the *existing* function, registry, idiom or call site it reuses, with a path.
  "Follows the existing pattern" without a path is not an audit.
- **Surface the new thing.** If anything genuinely new was introduced — a new
  policy line, a new predicate, a new flow — say so plainly and early, even when
  it is justified. Burying it is the failure this skill exists to catch.
- **Report your own mistakes.** Self-caught errors, deviations from an approved
  plan, and rules you broke and fixed all belong in the report. He is calibrating
  how much to trust the work; hiding a caught mistake makes every other claim
  worth less.
- **Uncommitted means uncommitted.** State exactly what is committed, what is
  only in the working tree, and what is in a worktree. Never let "done" blur into
  "landed".

## Structure

Keep it scannable. He reads this to rebuild a mental model in under a minute.

### 1. Arc — one paragraph
The governing goal, and the chain that led to the current step. Not history for
its own sake: only the links that explain *why this is what we're doing now*.

### 2. Vừa xong — with evidence
What completed since the last checkpoint, each with its real output quoted. A
table works well when there are several independent pieces.

### 3. Đang chạy / đang chờ
Anything in flight (a build, a gate, a peer session), and what it will decide.

### 4. Audit kỷ luật — the part he asked for
For each change, a row: what it does, and **which existing mechanism it reuses**
(with file path). Then, separately and explicitly, anything new. If there is
nothing new, say that, and say what it would have looked like if you had cheated
— that shows the audit was real.

Also check, and report on:
- Did any approved plan get deviated from? Why, and was it measured?
- Was a documented intentional divergence (`paper/NIM-REF.md`) respected rather
  than "fixed"?
- Were guards proven red before being trusted?
- Any comments added? (House rule is zero.)

### 5. Chưa làm / còn nợ
Explicitly including what was NOT verified. A recap that lists only successes
reads freshly audited and is more dangerous than an obviously stale one.

### 6. Next
The single next action, and whether it needs his sign-off. A commit follows the
project's rule: ask, unless its CLAUDE.md lets the agent commit on its own.

## Anti-patterns

- Reciting the plan back as if it were progress.
- "Everything is green" with no number, no binary named, no log quoted.
- An audit that only lists what was reused, omitting the one new thing.
- Quietly dropping a step that was in the approved plan and not saying so.
- Padding with history he already lived through — he lost context on the *state*,
  not on the project.
- Ending without a concrete next action.
