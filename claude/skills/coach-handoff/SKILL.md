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

   **Then measure the board.** `~/nerdtools/claude/scripts/arc-context.py` inlines it only up to
   `INLINE_LIMIT` lines; past that the next coach is handed a truncation instead of a board, and
   nothing tells it so. Check the number against the constant, and if the board is over, cut it —
   the history belongs in the ledger and the worker detail belongs in the cards. A board that
   does not fit is a board that will not be read.

        wc -l <workspace>/.coach/<name>.md
        grep INLINE_LIMIT ~/nerdtools/claude/scripts/arc-context.py

5. **Write the handoff to `<workspace>/.coach/reentry.md`. Do not print a prompt for the human
   to paste.** The hook inlines that file to the next coach ahead of the board, so the human's
   entire re-entry is opening a session in `.coach/` — they retype nothing.

   This is not tidiness. A prompt that lives only in a terminal scrollback is a **blind format**:
   nothing audits it, and it has now shipped a dead session address and a retired practice on two
   separate handoffs. A file is an artifact the next session can check against the registry and
   against the playbook. The same reasoning that moved orders out of the human's hands moves the
   prompt out of them.

   What `reentry.md` holds, and nothing more:
   - the one sentence saying what is in flight **right now**, which is the only thing the board's
     structure cannot express;
   - **the human's standing rules as they actually are today.** Read them off the board, never
     from a template in this file — a default written here is exactly how a retired practice
     reaches a fresh coach. If the board and your memory disagree, the board wins.
   - **addresses verified at write time.** A session name is a live fact, not a durable one: pids
     die and are replaced. Re-derive every name from the registry in the same beat as writing it,
     and prefer identifying a worker by its **cwd**, which outlives the process.
   - what it must NOT trust, and what it must re-measure first.

   No tool names, no slash-commands, no harness behaviour — the next coach may not be running the
   same harness. Say what to do, not which button to press.

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
- **Never ship a standing rule from a template.** Every rule written into `reentry.md` is copied
  from the board, which the human corrects; a rule typed from memory or from an example in this
  file survives its own retirement. Both handoff defects seen so far were of this shape.
- **A session address is not durable state.** Names like `omp-<pid>` die with the process. Verify
  every address against the registry at write time, and identify a worker by the directory it
  stands in.
