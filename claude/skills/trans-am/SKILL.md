---
name: trans-am
description: Run the rest of an approved metascript-recompiler arc at full speed when every remaining step only has to follow its reference (Nim for the core, typescript-go for TS-surface mechanisms, paper/ULTRALOCK.md across threads). Parallel path-disjoint lanes of Sonnet subagents trace each step with /trace-ref and prove it in the edit loop; each slice that passes its ready check goes to the gate queue as soon as it is ready (slices ready together go as one branch through one gate), and its reds are fixed in parallel until it lands. Use when the user types /trans-am, or asks to finish an arc "một mạch" with parallel agents.
---

# /trans-am

Speed mode for an arc whose remaining work is known ground: the reference already has the
mechanism, the card already lists the steps, nobody has to invent anything. Each step is proven
by `/trace-ref` and its edit-loop pin instead of a gate. A slice goes to the gate queue the
moment it passes its ready check, because a held slice waits for nothing; slices of the arc that
are ready at the same moment go as one branch through one gate, because each gate holds a
shared host while nothing is gained by running them apart.

**Not for:** a NEW MECHANISM the trace proved (workspace `~/metascript/CLAUDE.md` §Language
behaviour, "NEW MECHANISM is a finding a trace proves"), a TS-vs-safety decision, or anything
the card lists under "Questions waiting on the person". Those are parked at a named site and
reported; the run continues around them.

## Hard rules

- **The person approved the run, not every decision in it.** Push, `land --no-gate`, deleting
  someone else's work, and a proven NEW MECHANISM still stop for the person.
- **A question is answered by `/trace-ref` first.** If the reference settles it, act; if not
  (TS loss, two reference-faithful paths, a part neither reference has after the read), park
  it with a `/cto-report` for the person; never guess, and never let hours choose.
- **Lanes are path-disjoint.** Each lane owns a list of paths; an edit another lane's file needs
  goes to the merge-final step. Choose how many lanes run at once from the dependency graph and
  measured host pressure (workspace §Coaching), not a fixed count.
- **One agent per step, not one agent per lane.** A step returns, the coordinator audits it,
  the next step of that lane starts. A lane-long agent drowns its own context.
- **The coordinator audits in the main session** (global rule "Audit by yourself"): it reads
  every step's diff, rechecks a red/green claim on a sample, and refuses a name fallback, a new
  mechanism, a silent catch-all, or the reference named in source, docs or commit messages.
- **The only gate is the gate queue's**, because only its gate earns a land verdict: never run
  `tools/gate.sh` yourself. Per commit: `./msc check src/index.ms` and the step's pin red on the
  old compiler, green on the candidate, C plus `--target=js`; the candidate build and its checks
  are one heavy job through `run-remote.sh` (workspace §Worktrees), off the Mac.
- **Shared state is written by the coordinator only:** the arc card, `paper/NIM-REF.md`,
  `known-red.json`. Agents propose changes in their report.

## Procedure

1. **Sync.** Rebase the arc branch onto the latest `main`; the base is the old-compiler control
   of every red/green check, built remotely when needed (lane contract).
2. **Inventory.** Read the card's Done-when, State and Next; grep what is left (raw counts are an
   upper bound). Mark each item: follows the reference (go), waits on a neighbour arc (park
   with the neighbour's name), needs the person (park plus `/cto-report`).
3. **Cut lanes.** Group the go items by the paths they edit. Write each lane's owned-path list,
   its ordered steps, and whether it consumes another lane's unlanded behaviour. Put cross-lane
   edits (a field one lane deletes and another lane's file reads) in a merge-final step.
4. **Provision.** Lane 1 runs in the arc worktree. A lane that runs at the same time as another
   gets its own worktree, because a worktree takes one writer: off `main`
   (`~/nerdtools/claude/tools/wt.sh new <arc>-lane-<x>`) when it consumes nothing unlanded, so
   it can land alone, otherwise off `wt/<arc>`, landing with it. A lane that runs after another
   is commits in the arc worktree, since it needs no second writer. Note each lane in the card's
   State.
5. **Brief and launch.** One background `Agent` per step, `model: "sonnet"`, prompt = the lane
   contract below plus the step. Run ready lanes side by side (hard rule 3).
6. **On each return:** audit the diff, rerun one pin red/green, apply its NIM-REF proposals,
   update the card State, start the lane's next step. A step that came back with a question
   goes through rule 2 of the hard rules.
7. **Merge dependents.** Rebase dependent lanes onto the arc branch, resolve, run the
   merge-final step, `./msc check`. Reset a lane worktree to the arc tip (`git reset --hard`)
   before giving it a new step; its own commits are rebased copies by then. After rebasing onto
   a moved `main`, `check` catches the semantic conflicts a clean text merge hides.
8. **Ready and submit as each slice finishes.** Read `~/metascript/docs/LANDING.md` first: it
   decides what proof a slice needs and which lanes its gate runs.
   - When a lane finishes and another is finishing in the same window, merge them into
     `wt/<arc>` and prove and submit that one branch. When it finishes alone, it goes alone; do
     not hold it for a lane still in work, because the held slice only waits.
   - Rebase on `main`, list what the change reaches (`tools/gate.sh --dry-run`, then who reads
     the changed code), and run `gate-queue ready-check <slice> <host>` in the background.
   - Add through `run-remote.sh` only the part of each reached lane the change touches (the named
     corpus programs, the owner modules, the guards, the self-host chain when the compiler
     changes what it does to itself). A whole lane or a full corpus before submit duplicates the
     gate on a shared host.
   - Record what ran with `gate-queue accept <slice> "<command: pass count per cell; …>"`, then
     `gate-queue submit <slice>` with `--programs`, `--with` or `--full` for the reach beyond
     the core, and `gate-queue wait <slice>` in the background: 0 landed, 1 red
     (`.gate-host/queue/<slice>.red`), 2 unready (redo the ready check), 3 GREEN not landed (fix
     what `.unlanded` names, then `wt.sh land <slice>`; a rebase resolved by hand gates again).
9. **Answer a red as LANDING §Answering a red says.**
   - Reproduce each named failure with the exact lane command on a candidate of the tip.
   - Name the reach the proof missed and add that check, then brief path-disjoint fix lanes as in
     step 5 (each red a `/trace-ref` repro).
   - A red that is not the slice's is proven so by the same command on a candidate of `main`, or
     by the rerun that passes, before resubmitting.
   - A second red writes its cause in the card; a third goes to the person with each red and its
     cost. Repeat 8–9 until landed.
10. **Report.** Lead with each slice's queue verdict and the diff against known red, then what
    landed per lane and what is parked, with why. Retire landed lanes with `wt.sh rm` from outside.

## Lane contract — paste into every agent brief, then add the step

```
You are lane <X> of arc <arc> in ~/metascript/recompiler. Worktree <path>, branch <branch>.
Work only there: start every Bash command with `cd <path> &&`, use absolute paths. Do not
touch other worktrees, the main checkout, ~/.metascript, the arc card, paper/NIM-REF.md or
src/test/known-red.json. Never push, land, submit to the gate queue, run tools/gate.sh, the
corpus or SAN lanes, or `rm -rf out`.

Owned paths: <list>. Do not edit anything else; an edit another path needs goes in your report.

Read first: <path>/CLAUDE.md, <path>/paper/local.md, ~/metascript/recompiler/docs/LANG-PREFERENCE.md,
~/nerdtools/claude/playbooks/comment.md (comments default to zero).

Every step: invoke the `trace-ref` skill and follow it. Reproduce with a minimal .ms in
/tmp/<lane>/ on the old compiler. Pin the mechanism (emit C). Read the reference the layer
selects (~/projects/nim/compiler, typescript-go, or paper/ULTRALOCK.md across threads) and cite
file:line. Check the paper/NIM-REF.md entry. Fix by following the reference. If a part of the
fix is one neither Nim nor typescript-go has after reading both, stop that item and report it
as NEW MECHANISM with the evidence; do not implement it. Never write "Nim" in source,
comments, docs or commit messages; say "the reference".
Fail loud: a missing symbol is `throw new Error("internal: …")` naming the case, never a
lookup by name. Close by deletion: a name-keyed table, field or parameter with no reader left
is deleted in the same step.

Per commit, no gate: `./msc check src/index.ms` is clean. Build the candidate and run its checks
in one heavy job, off the Mac:
`~/metascript/.gate-host/run-remote.sh --cores 8 --job "<arc>-<X>: <step>" -- sh -c
'cp "$(command -v msc)" builder && ./builder build src/index.ms --danger --lto=off
--output=msc-cand && <checks>'`. The builder and msc-cand sit at the tree root so they load this
tree's std and runtime; the remote `msc` (the ~/.metascript/BUILD commit) is the old compiler,
or build the base in the same call when the base is newer and the gap could explain the red.
Build one compiler at a time, never two in parallel, because each self-host build holds about
4 GB and a host runs short with two. The pin goes red on the old compiler and green on msc-cand,
on C and on `--target=js` where JS has the feature; run `./msc-cand test <file> --tests-in-dir`
for the pin and each file you changed. Add a variant on a second axis (backend, type, arity or
nesting); one case is not a pin. Place pins by tier (src/test/CLAUDE.md) and register them in
the tier index. A corpus pin's directives (`@xfail(raiser)`, `@skip-js`) are checked with a
targeted `MSCORPUS_ONLY` run before the report. Commit each step through the `split-commit`
skill. Never `--no-verify`: if the pre-commit loss guard fires on a deletion you meant, make
the commit show the intent; if it still fires, stop and report its output.

To stop a command of yours that hangs, stop it by its own handle: the background task id, or
the PID of the process whose command line you started. Never kill by image name
(`taskkill /IM msc.exe`, `pkill msc`): other sessions' gates run the same binary, and a killed
test lands in their land verdict as a red they did not cause.

Final message, 60 lines at most, no narrative. Per step: the commits; the reference file:line
followed; the pins with one line of red/green evidence each; what you did not verify; proposed
NIM-REF updates (ID plus the new verdict line); items skipped and why (NEW MECHANISM, needs the
person, blocked by another lane's path).
```
