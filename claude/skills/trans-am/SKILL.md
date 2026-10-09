---
name: trans-am
description: Run the rest of an approved metascript-recompiler arc at full speed when every remaining step only has to follow its reference (Nim for the core, typescript-go for TS-surface mechanisms). Parallel path-disjoint lanes of Sonnet subagents trace each step with /trace-ref instead of gating it; then everything is gated once, independently, every lane runs even after a red, and the reds are fixed in parallel until green. Use when the user types /trans-am, or asks to finish an arc "một mạch" with parallel agents and one final gate.
---

# /trans-am

Speed mode for an arc whose remaining work is known ground: the reference already has the
mechanism, the card already lists the steps, nobody has to invent anything. The run trades the
per-step gate for a per-step `/trace-ref`, then pays for it with one gate at the end.

**Not for:** a step that needs a pass, structure or protocol the reference and our design both
lack (NEW MECHANISM), a TS-vs-safety decision, or anything the card lists under "Questions
waiting on the person". Those are parked at a named site and reported; the run continues
around them.

## Hard rules

- **The person approved the run, not every decision in it.** Push, `land --no-gate`, deleting
  someone else's work, and NEW MECHANISM still stop for the person.
- **A question is answered by `/trace-ref` first.** If the reference settles it, act. If it
  does not (TS loss, two reference-faithful paths, a mechanism the reference lacks), write a
  `/cto-report` for the person and park the item; never guess.
- **Lanes are path-disjoint.** Each lane owns a list of paths; an edit another lane's file needs
  goes to the merge-final step. Concurrency ceiling: the workspace's tested worker count
  (`~/metascript/CLAUDE.md` §Coaching: two).
- **One agent per step, not one agent per lane.** A step returns, the coordinator audits it,
  the next step of that lane starts. A lane-long agent drowns its own context.
- **The coordinator audits in the main session** (global rule "Audit by yourself"): it reads
  every step's diff, rechecks a red/green claim on a sample, and refuses a name fallback, a new
  mechanism, a silent catch-all, or the reference named in source, docs or commit messages.
- **No gate before the end.** Per commit: `./msc check src/index.ms` and the step's own pin red
  on the base `./msc`, green on the candidate, C plus `--target=js`. Lanes, corpus and SAN wait
  for the final gate.
- **Shared state is written by the coordinator only:** the arc card, `paper/NIM-REF.md`,
  `known-red.json`. Agents propose changes in their report.

## Procedure

1. **Sync.** Fast-forward or rebase the arc branch onto the latest `main`. Rebuild the builder
   `./msc` from that base and keep a copy outside the tree: it is the old-compiler control of
   every red/green check. Check `df` and load.
2. **Inventory.** Read the card's Done-when, State and Next; grep what is left (raw counts are an
   upper bound). Mark each item: follows the reference (go), waits on a neighbour arc (park
   with the neighbour's name), needs the person (park plus `/cto-report`).
3. **Cut lanes.** Group the go items by the paths they edit. Write each lane's owned-path list
   and its ordered steps. Put cross-lane edits (a field one lane deletes and another lane's file
   reads) in a merge-final step.
4. **Provision.** Lane 1 runs in the arc worktree. Every other lane gets
   `~/nerdtools/claude/tools/wt.sh new <arc>-lane-<x> wt/<arc>` with `MSC_BUILDER` set to the
   fresh builder. Note each lane in the arc card's State.
5. **Brief and launch.** One background `Agent` per step, `model: "sonnet"`, prompt = the lane
   contract below plus the step. Run both lanes at once.
6. **On each return:** audit the diff, rerun one pin red/green, apply its NIM-REF proposals,
   update the card State, start the lane's next step. A step that came back with a question
   goes through rule 2 of the hard rules.
7. **Merge.** Rebase the other lanes onto the arc branch, resolve, run the merge-final step,
   build once, run `./msc check`. Reset a lane worktree to the arc tip (`git reset --hard`)
   before giving it a new step; its own commits are rebased copies by then. After rebasing onto
   a moved `main`, `check` catches the semantic conflicts a clean text merge hides.
8. **Gate once, independently.** `tools/gate.sh` in the arc worktree, not the land queue.
   Launch it detached (`nohup … & disown`), since a background tool call dies at its time limit,
   with a large `GATE_WAIT_MAX` (0 and -1 mean "do not wait": exit 75 on a busy box). Before it:
   a smoke build of C, JS and Raiser hello, `df`, and a builder new enough to build the tree
   (a std change the previous compiler cannot digest needs a feature-flag `when` guard, as the
   reference guards `system.nim` with `nimHasX`). When it stops on a new red, run the lanes it
   did not reach (`--lanes <rest>`) on the same candidate so one round shows every red. Re-run
   suspected environmental reds per file on a fresh candidate before briefing a fix lane.
   Summarise per lane: new reds, stale known reds, and the steps whose trace looked thin.
9. **Fix round.** Group the reds by the paths their fixes touch into path-disjoint fix lanes,
   brief them as in step 5 (each red is a `/trace-ref` repro), merge, gate again. Repeat 8–9
   until green.
10. **Report.** Lead with the gate verdict and the diff against known red. Then list what landed
   in the branch per lane and what is parked, with each parked item's reason. A land goes
   through the repository's normal queue, decided by the person or the card.
   Retire extra lane worktrees with `wt.sh rm` from outside them once merged.

## Lane contract — paste into every agent brief, then add the step

```
You are lane <X> of arc <arc> in ~/metascript/recompiler. Worktree <path>, branch <branch>.
Work only there: start every Bash command with `cd <path> &&`, use absolute paths. Do not
touch other worktrees, the main checkout, ~/.metascript, the arc card, paper/NIM-REF.md or
src/test/known-red.json. Never push, land, run tools/gate.sh, the corpus or SAN lanes, or
`rm -rf out`.

Owned paths: <list>. Do not edit anything else; an edit another path needs goes in your report.

Read first: <path>/CLAUDE.md, <path>/paper/local.md, ~/metascript/docs/CODE-STYLE.md,
~/nerdtools/claude/playbooks/comment.md (comments default to zero).

Every step: invoke the `trace-ref` skill and follow it. Reproduce with a minimal .ms in
/tmp/<lane>/ on the base compiler ./msc. Pin the mechanism (emit C). Read the reference in
~/projects/nim/compiler and cite file:line. Check the paper/NIM-REF.md entry. Fix by following
the reference. If the fix needs a pass, structure or protocol that both the reference and our
design lack, stop that item and report it as NEW MECHANISM. Do not implement it.
Never write "Nim" in source, comments, docs or commit messages; say "the reference".
Fail loud: a missing symbol is `throw new Error("internal: …")` naming the case, never a
lookup by name. Close by deletion: a name-keyed table, field or parameter with no reader left
is deleted in the same step.

Per commit, no gate: `./msc check src/index.ms` is clean. Build the candidate with
`./msc build src/index.ms --gc=drc --danger --lto=off --output=<path>/msc-cand`; it must sit at
the worktree root so it loads this tree's std and runtime. The step's pin goes red on ./msc and
green on ./msc-cand, on C and on `--target=js` where JS has the feature. Run
`./msc-cand test <file> --tests-in-dir` for the pin and for each file you changed. Add a variant
on a second axis (backend, type, arity or nesting); one case is not a pin. Place pins by tier
(src/test/CLAUDE.md) and register them in the tier index. A corpus pin's directives
(`@xfail(raiser)`, `@skip-js`) are checked with a targeted corpus run before the report. Commit
each step through the `split-commit` skill. Never `--no-verify`: if the pre-commit loss guard
fires on a deletion you meant, make the commit show the intent; if it still fires, stop and
report its output.

The machine is shared: one build at a time, no long suites; check `df -h /System/Volumes/Data`
before a large build.

Final message, 60 lines at most, no narrative. Per step: the commits; the reference file:line
followed; the pins with one line of red/green evidence each; what you did not verify; proposed
NIM-REF updates (ID plus the new verdict line); items skipped and why (NEW MECHANISM, needs the
person, blocked by another lane's path).
```
