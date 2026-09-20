---
name: coach-handoff
description: Prepare a coach session to be cleared — flush its durable state to the board and the ledger, then emit the short handoff prompt the next session starts from. Use when the user types /coach-handoff, when a coach session is getting long, or before /clear or /compact in a session that supervises worker sessions. Requires the workspace to run coaching (its CLAUDE.md turns it on and names .coach/).
---

# coach-handoff — flush the board, then hand off

A coach is more clearable than a worker: a worker's value accumulates in its context, a
coach's value is supposed to be on disk by design. So `/clear` beats `/compact` for a coach —
a board the coach curated is better than a summary the harness generated out of git output
and transcript parsing.

**That only holds if the board is written BEFORE the clear.** This skill writes it.

The practice this serves: `~/nerdtools/claude/playbooks/coach.md`.

## What dies with the session, and therefore what the board must carry

Not the worker's progress — that is in its `.wt/<name>.md` card and in git, and copying it
here only creates a second table to keep in step. What dies is:

- **the reason behind a judgment** — "challenge its inferences, not its diligence" is a
  conclusion; without the one line that produced it the next coach reads it uncalibrated;
- **the live detail of an open thread** — "it will report AE/PAE on the FMA question" does
  not say which lever was handed over, so the next coach cannot tell a complete answer from a
  partial one;
- **negative knowledge** — what was checked and found absent. A fresh coach re-greps (cheap)
  or assumes (expensive);
- **which instructions were the coach's** rather than the brief's.

One asymmetry to remember while writing: **the workers still remember everything the previous
coach said.** After the clear they know more about the thread than the coach does, and they
are an interested party, so recover from the board, not by asking them.

## Steps

1. **Read the current picture, artifacts only.** `ListAgents` for who is alive and busy;
   `git log --oneline -3` and `git status --short` per worktree; the `State:` line of each arc
   card; the tail of `.coach/log.tsv`. Do not read worker transcripts — this is a flush, not
   an investigation.

2. **Reconcile the board** (`<workspace>/.coach/<name>.md`), overwriting it:
   - the worker table: session name, its card, **what I am waiting on** — one line each;
   - **open threads I own**, each with the one line of reasoning that produced it and whether
     it is verified or merely ordered;
   - **cross-arc facts no card owns yet** — the things only a coach standing over several
     arcs can see;
   - **standing judgments**, each with its evidence in the same line;
   - anything ordered that was marked as the coach's addition rather than the brief's, so the
     human can still veto it after the handoff.
   Delete what has become derivable since it was written: if a worker has since recorded a
   decision in its card, the board points at the card instead of repeating it.

3. **Append the missing ledger rows** to `.coach/log.tsv` — one row per intervention since the
   last flush: `date, time, manager, target, kind, subject, outcome`. Fill in the outcome of
   earlier rows that have since resolved; a row whose outcome is still unknown says so. This
   file is what makes the playbook's open questions answerable, so an unflushed session is a
   measurement lost.

4. **Run the acceptance test before emitting anything.** Answer these three from the board and
   the ledger alone, without asking a worker:
   - what is each live worker doing;
   - what am I waiting on from each;
   - which of the standing instructions are the coach's rather than the brief's.
   Every question you cannot answer is a hole in the board, not a reason to ask a worker.
   Go back to step 2 and fill it.

5. **Emit the handoff prompt** — short, and pointing at files rather than restating them,
   because restating is what the board already did. Print it in a fenced block for the user to
   paste after `/clear`:

   ```
   You are the coach for <workspace>. Read, in this order:
   ~/nerdtools/claude/playbooks/coach.md (the practice)
   <workspace>/CLAUDE.md (what this workspace turns on)
   <workspace>/.coach/<name>.md (the board — what I am waiting on)
   <workspace>/.coach/log.tsv (the ledger — what has been ordered and what came of it)
   Then ListAgents, and the .wt/ card of every worker it lists as alive.
   Do not read worker transcripts unless the board is behind.
   Orders to workers are drafted for me and sent only after I approve.
   Report the verdict, not the detail.
   ```

   Adjust the last two lines to whatever the human's standing preferences actually are; do not
   ship defaults that contradict them.

6. **Say what was flushed and what was left open**, in three lines or fewer, then stop. Do not
   clear on the user's behalf — `/clear` is theirs to type.

## Traps

- **Flushing after the clear is not possible.** If the context is already tight, flush first
  and investigate never; a thin but honest board beats a rich one that was never written.
- **Do not copy worker state into the board to make it look complete.** A board that
  duplicates the cards goes stale the moment a worker commits, and the next coach trusts it.
- **An order sent but unverified is an open thread, not a finished one.** Record which it is;
  the next coach will otherwise read "ordered" as "done".
- **Do not fabricate ledger outcomes.** An intervention whose effect was never checked has an
  empty outcome column, and that emptiness is itself the measurement.
