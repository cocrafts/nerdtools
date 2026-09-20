---
name: worker-handoff
description: Prepare a worker session to be replaced — bring its arc card to the bar where a fresh session resumes without asking a question only this one could answer, verify the card by script rather than by reading, then stop. Use when the user types /worker-handoff, before a worker is cleared or swapped to another agent, or when a coach asks for handoff prep. The counterpart of coach-handoff, which is for the supervising session and writes .coach/; this one is for the arc session and writes .wt/<name>.md.
---

# worker-handoff — the card is the successor's only inheritance

A coach is clearable because its value is on disk by design. **A worker is the opposite:**
its value accumulates in its context, and the only part that survives is its
`~/metascript/.wt/<name>.md` card and its commits. Everything else — why a number was
rejected, which of three approaches was tried and abandoned, what the gate's skip line
actually means — dies silently.

So this is not "update the card". **State the bar:**

> A fresh session must resume from the card alone, without asking a question only you
> could answer.

Measured: *"update the card"* produces a card update; the bar above produced six real gaps
in one run and fifteen dead commit references in another.

## 1. Verify by script, never by reading

The strongest finding this ritual has produced came from refusing to read. A card that read
beautifully was broken **only where a fresh session actually uses it** — at `git show`. Fifteen
of its commit references were pre-rebase hashes its own rebase had destroyed.

Run this **with the worktree as cwd**:

```sh
cd <the worktree>            # NOT the workspace root
for s in $(grep -ohE '\b[0-9a-f]{7,40}\b' <card> | sort -u); do
  git cat-file -e "$s^{commit}" 2>/dev/null || continue
  git merge-base --is-ancestor "$s" HEAD || echo "UNREACHABLE $s  $(git log -1 --format=%s $s)"
done
```

Four things that loop gets wrong if you change it:

- **Run it outside a git repo and it prints empty**, because every `cat-file` fails and
  `continue` swallows it. A pass that cannot fail is worse than no check. Prove it can go red
  before you trust an empty run.
- **Test reachability, not existence.** `cat-file -e` alone still resolves a rewritten commit
  until it is garbage-collected, so it reports clean when it is not.
- **Compare against your own branch (`HEAD`), not `main`.** Your unlanded commits are not
  ancestors of `main`, and counting them as corpses is a false alarm. This error has been made
  in both directions.
- **An unreachable sha is not automatically dead.** Work in flight fails the same test for the
  opposite reason. Name work in flight by **subject**, not by sha, and the invariant then holds
  continuously instead of only after a land.

## 2. The invariant is EMPTY, not "these known corpses"

When you fix a dead reference, **delete it** — including a hash inside the sentence explaining
that the hash is dead.

This was paid for: a first pass rewrote dead hashes into `old -> new` notes on the card, and
the loop still printed four, because **the note re-injected the dead hashes into the very text
the loop greps.** The card poisoned its own check.

A card reading *empty* survives. One reading *exactly these corpses* degrades into a list
nobody re-derives, silently absorbs the next dead hash, and trains its reader to skim.

## 3. Anchor to what a rewrite cannot destroy

A sha is not a stable anchor. Rebase rewrites it; a force push rewrites all of them at once.
Where the card or a doc says *"these numbers were measured at `<sha>`"*, the honest anchor is
the **tree hash plus the subject** — the tree is what a gate run actually measured, and it
survives both rebase and rewrite:

```sh
git rev-parse HEAD^{tree}
git log --format='%T %h %s' <branch> | grep "^<tree>"     # still navigable
```

## 4. What the successor does NOT share with you

Write for a reader with none of your context, and check three classes explicitly:

- **A different agent.** If the successor is not the same harness, every `/slash-command`, every
  named tool, and every "ask with the options enumerated" is a reference it cannot resolve.
  Say what to do, not which button to press.
- **A moved base.** Do **not** rebase as your last act. A rebase rewrites every sha the card
  cites, so it belongs to the **first** act of the next session with the references fixed in
  the same beat — never to a session that can no longer fix them. Say in the card that it is owed.
- **A number's provenance.** A figure with no record of how it was taken cannot be re-taken.
  Give it the conditions, the sample count, and the commit or tree its binary came from.

## 5. The half-finished mechanism

Name, unmissably, any goal where **partial work moves the number not at all** — two independent
causes where closing one changes nothing. A successor that closes one and measures no movement
reads its own success as failure, and there is no cheaper way for it to learn this than a
sentence you write now.

## Stop

Commit the card's own repo changes if any; the card itself is outside git. Do not start the
next work item, do not rebase, do not land.

Report **what you found**, not that you are done. Three runs of this ritual have produced real
defects every time; a report that says "card is current" is evidence the bar was read as a task.
