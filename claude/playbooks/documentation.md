# Documentation — what a doc owns, and what it points at

Read this before writing or editing anything under `docs/`, a README, or a design note.
Unlike `coach.md`, this is a rule and not a log: it does not carry dates and it is not
provisional.

## Source code is the truth

The repo already answers *what the code is*: grep gives back a type's fields, a function's
signature, which file holds what, what a commit changed. A doc that restates any of it has
made a second copy that drifts, and the copy is the one that lies first.

So a doc exists for exactly the part the code cannot say about itself.

## The test, before every line

**Can a reader grep this back out of the repo?**

- **Yes** → name the path and the symbol, and stop. `src/void3d/scene.ms` `Object3D`, not
  the field list.
- **No** → the doc owns it. Write it in full, here, now. This is the whole reason the file
  exists, and it is the cheapest it will ever be to write.

## What a doc owns — these exist nowhere else, so write them

- **A number that was measured** — with the command, the conditions, and the tree it was
  taken on. `sprites.present 2.5 → 1.8 ms, interleaved A/B, box quiet at 9–13% CPU, six
  alternating pairs, lower in all six.`
- **What was tried and rejected** — the approach, and the fact that killed it. A rejected
  path leaves no trace in the code, so without the doc the next session pays for it twice.
- **An anchor into another repo** — `Heaps' multiply3x4inline (Object.hx:772)`,
  `bevy_ecs/src/hierarchy.rs:154 at 2bddbdfd7`. Our grep cannot reach these, which makes
  them the most valuable lines in any doc here. Copying foreign code verbatim is right for
  the same reason.
- **Why this shape and not the other** — the constraint that forced it. A trap that cost a
  run, an invariant a reader would violate on the first try, a number that will not move
  until two separate things are both closed.

## What a doc points at — name it, do not restate it

- Type shapes, field lists, signatures.
- Which file holds what.
- What a commit did — `git log` has it.

## Keep a pointer alive

- Point with a **symbol and a path**, not a line number alone: a rename shows up as a failed
  grep, a shifted line does not.
- A measurement names the **tree** it was taken on — `git rev-parse HEAD^{tree}` survives a
  rebase and a force push, a commit sha does not.
- When a pointer's target is gone, the doc is wrong, not merely stale. Fix it in the commit
  that moved the target.

## A card is not a doc

An arc's card is untracked, lives on one machine, and is deleted once its "Done when" holds.
A finding written there is a finding scheduled for deletion, invisible to review and to every
other machine. So the card says **where we are** — Goal, Done when, State, Next, Neighbours —
and the repo's tracked docs say **what we know**. The card points at them and never copies
them.
