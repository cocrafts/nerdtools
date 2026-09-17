---
name: split-and-conquer
description: disciplined workflow for non-trivial multi-step changes — decompose into independent verified items, run /tmp probes before executing each one, get user consensus per step, smoke-test between steps. Use whenever a task has multiple loosely-coupled subtasks where some may turn out invalid on closer inspection (refactors, migrations, multi-file features, cleanup passes).
---

# /split-and-conquer

A safety-rail workflow for **non-trivial multi-step changes** that touch more than one file or concept. Prevents the "confident charge" failure mode: 5 items planned, item 2 silently wrong on closer inspection, but the agent steamrolls through all 5 and breaks the working tree.

The discipline: **verify each item against actual source before executing it**, with `/tmp` probes for any compiler/runtime/library doubt, and explicit user consensus per step.

## Usage

```
/split-and-conquer                       # invoke against the current task in context
/split-and-conquer <one-line task>       # invoke with an explicit task statement
```

There are no flags. The skill is a workflow, not a tool — it shapes how the assistant behaves for the duration of the task.

## When to invoke

Best fits:
- Refactor spanning >3 files
- Cleanup / dedup pass where some "duplications" may not be on inspection
- Migration with multiple loosely-coupled steps
- Multi-step plan where individual items may turn out invalid, unnecessary, or already done
- Any task where the user signals caution ("be careful", "don't fuckup", "verify each step", "kỹ hơn")

Bad fits (don't use):
- Single-file edits
- Trivial bug fixes
- Time-pressured hot fixes
- Tasks with one obvious mechanical step

## The workflow — 5 stages

### Stage 1 — DECOMPOSE (no code yet)

Inventory the work and produce a **candidate ordered item list**. Each item must be:
- **Independent** — no item blocks the next; can be skipped without breaking the rest
- **Small** — small enough that one item = one verify + one execute + one smoke-test
- **Ordered** easiest → hardest, OR least-risk → most-risk (mention which ordering you chose)

This is a **candidate** list — Stage 2 (BATCH PRE-VERIFY) will filter out obvious invalids before TodoWrite gets populated. Don't worry about over-including at this stage; better to surface a candidate and filter than to silently drop something the user wanted.

Brief the user **CTO mode** (per `~/.claude/CLAUDE.md` "CTO mode" section): high-level shape, trade-off, what won't be touched, recommendation. **No code yet.** Wait for user alignment on the candidate list (or reordering) before moving on.

### Stage 2 — BATCH PRE-VERIFY (no code yet)

Before populating TodoWrite, do a **lightweight batch sanity check** across all candidate items in one pass:

For each candidate item, do a **cheap read/grep** (NO `/tmp` probes yet — those come in Stage 4a):
- Does the duplication / pattern / opportunity it claims actually exist in the source?
- Has it already been done in a way the Stage-1 inventory missed?
- Does it conflict with a stated constraint (don't touch X, don't change Y)?
- Is it sub-trivial (1-2 lines, no real DRY/clarity win)?

Classify each item as:
- **KEEP** — passes the cheap check, will move into TodoWrite
- **OBVIOUS-DROP** — clearly invalid at the cheap-check level; doesn't need full Stage-4a probe
- **DEFER-TO-3A** — survives the cheap check but has uncertainty that warrants the full per-item probe in Stage 4a

Brief the user **CTO mode** with the filtered list:
- "Out of N candidates, K survived. Dropped M: <one-line reason each>. M' carry uncertainty for the deep verify in Stage 4a."
- The reasons matter — they're the most informative output of this stage. They show what the Stage-1 inventory got wrong on first pass.

Wait for user alignment before moving to Stage 3.

**Why this stage exists**: populating TodoWrite with items that turn out invalid on the first read is noise. Batch-filter the obvious-invalid before committing to per-item discipline. Keeps the per-item loop focused on items that genuinely need it.

### Stage 3 — TODO

Once the filtered list is aligned, register the surviving items via **TodoWrite** — one entry per item, in the agreed order. This is now the canonical progress board.

### Stage 4 — PER ITEM, one at a time

For each item, in order, run all six sub-steps:

#### 4a. VERIFY (the most important step)

Trace the claim against actual source:
- `Read` the file(s) the item targets
- `Grep` to confirm pattern / count occurrences
- Compare to what the Stage-1 inventory assumed AND what the Stage-2 batch pre-verify concluded

If there is ANY doubt about compiler behavior, library behavior, runtime semantics, or "will my proposed change actually compile/work" — **write a minimal probe under `/tmp/<task-name>-probe-<N>/`** and run it. Don't speculate. The whole point of this skill is to catch the cases where assumed-true items turn out false.

Items that came out of Stage 2 marked **DEFER-TO-4A** should get the probe treatment here — that's the entire reason they survived Stage 2.

Default stance: **skeptical**. Re-ask "is this still valid?" with fresh eyes — even after Stage 2 said keep, Stage 4a can still find new reasons to skip.

#### 4b. CTO-BRIEF

Report the verification outcome in ONE of three shapes:

- **PROCEED** — "Item N still valid. Plan: <one-sentence shape>. Will touch: <files>. Will not touch: <adjacent stuff>. OK to execute?"
- **SKIP** — "Item N turned out invalid because <reason found during verify>. Recommend skip. The original concern is <still valid / already handled by existing code>."
- **BLOCKED** — "Item N has a surprising finding: <what>. Don't have a clean execution path. Need your input on <specific question>."

Keep each brief short — 3-5 lines. The user shouldn't have to load a file mentally to decide.

#### 4c. CONSENSUS

Wait for the user's explicit go. **Never auto-execute from CTO-brief alone.** A natural-language "ok" / "đi" / "go" / "proceed" is enough — but it must come from the user.

If the user asks for adjustment, loop back to 4a or 4b. If the user says skip, mark the todo as completed with a skip-reason and move to the next item.

#### 4d. EXECUTE

Make the change. **One focused chunk**, scoped strictly to the item. No drive-by improvements, no "while I'm here" edits. Adjacent issues become new items, not silent additions.

#### 4e. SMOKE

Run the project's smoke test. The test command depends on the project — look for clues:
- `package.json` scripts, `Makefile`, `build.ms`, `.github/workflows/` — pick the most-direct "does it still build + run" command
- For SDKs / libraries: a known-good example program
- For CLIs: invoking the binary with a baseline command
- For services: a curl / probe against the running process

If the project's smoke test isn't obvious, **ask the user before Stage 4d** what the smoke command is. Cache that for the rest of the session.

If smoke is **RED**, stop. Report failure + propose rollback. Do NOT continue to the next item while the tree is red.

#### 4f. MARK DONE

`TodoWrite` update: `completed`. Move to the next item.

### Stage 5 — FINAL REPORT

After all items have been processed (executed, skipped, or blocked):

- **Done** — list what was executed, with a one-line summary each.
- **Skipped at Stage 2 (batch pre-verify)** — list and reason; surfaces what the Stage-1 inventory got wrong on first read.
- **Skipped at Stage 4a (per-item verify)** — list and reason; surfaces what only deep verify caught.
- **Deferred / blocked** — open question that needs the user's input.
- **Net delta** — LOC moved/removed, files added/removed, file count change.

Brief CTO mode. **Do not commit, push, or open a PR** unless the user explicitly asks.

## Core rules

1. **ONE ITEM AT A TIME.** No batch execution.
2. **STOP ON RED.** Don't continue past a failing smoke test.
3. **PROBE BEFORE EXECUTE** when in any doubt. `/tmp` probes are the default verification tool.
4. **SKIP IS NORMAL** — the skill exists precisely because some items will turn out invalid. A run that skips 2 of 5 items is a successful run, not a failed one.
5. **CONSENSUS PER STEP.** User confirms before each execute.
6. **NO DRIVE-BY EDITS.** Touch only what the item scopes. New findings become new items.
7. **NO COMMIT WITHOUT ASK.** The skill never commits/pushes/PRs on its own.

## Anti-patterns this skill prevents

- "Confident charge" — executing 5 items where item 2 was silently wrong.
- "Pattern-match refactor" — assuming three things are duplicated because they look similar, without verifying they actually share behavior.
- "Speculative compiler claim" — saying "this works in MS" or "this library does X" without running a 10-line probe.
- "Batched commit" — bundling 5 separate items into one diff so a regression can't be bisected.
- "Drive-by improvement" — fixing an adjacent issue while doing item N, which then breaks item N+2 in a confusing way.

## Common probe shapes

When in doubt, the probe is the fastest path to certainty:

- **Compiler bug suspect** — minimal `.ms` file isolating the construct, build it, check codegen or runtime behavior.
- **Library API doubt** — 5-line script that exercises just that one call.
- **"Is this still duplicated?"** — grep the codebase for the pattern, `wc -l` the matches.
- **"Does this still build after the rename?"** — copy the affected file to `/tmp/probe-rename/`, do the rename, try to build just that.
- **"What does this AST look like?"** — for compilers / parsers: run with a debug flag against a tiny input.

Keep probes throwaway. Delete `/tmp/<task-name>-probe-*` directories at the end of Stage 4, or mention them in the final report so the user can inspect.

## Integration with TodoWrite

TodoWrite is the canonical progress board for this workflow:

**TodoWrite is only populated AFTER Stage 2 (batch pre-verify) filters the candidate list.** Stage-2 OBVIOUS-DROPs never enter TodoWrite — they're recorded only in the Stage 5 final report. This keeps the board clean and focused on items that genuinely need per-item discipline.

| Todo state | Meaning |
|---|---|
| `pending` | Item survived Stage 2, queued for Stage 4 |
| `in_progress` | Item is in Stage 4 (verify → execute → smoke) |
| `completed` | Item executed + smoke-green, OR skipped at Stage 4a with reason in the content |

A Stage-4a-skipped item gets marked `completed` with content rewritten to: `Skipped: <original item> — <reason>`. This preserves the audit trail at the end of the session.

If a Stage-4e SMOKE step goes red and is not recoverable in-session, mark the todo back to `in_progress` and stop — final report describes the failure.

## What you must do when invoked

Follow these steps. Do not skip.

### Step 1 — Confirm there's a task

If the user invoked `/split-and-conquer` without context, ask one sentence: "What's the task?" Then proceed.

If the user invoked it with context (e.g. mid-conversation: "let's do this refactor with split-and-conquer"), use the conversation's current task.

### Step 2 — Stage 1 (DECOMPOSE)

Inventory the work. Produce the **candidate** ordered item list. Brief CTO mode. Wait for user alignment.

**Do not skip the brief.** Even if the item list seems obvious to you, the user needs to see the candidates before any filtering happens.

### Step 3 — Stage 2 (BATCH PRE-VERIFY)

Do a single-pass cheap read/grep across all candidates. Classify each as KEEP / OBVIOUS-DROP / DEFER-TO-4A. Brief CTO mode with the filtered list + reasons for drops. Wait for user alignment.

**Do not populate TodoWrite yet.** The whole point of Stage 2 is to avoid noise.

### Step 4 — Stage 3 (TODO)

Once the filtered list is aligned, populate TodoWrite with the surviving items only. One entry per item, in the agreed order.

### Step 5 — Stage 4 loop

For each item in order: verify → brief → wait for consensus → execute → smoke → mark done.

### Step 6 — Stage 5 (FINAL REPORT)

Executive summary. Done / skipped-at-2 / skipped-at-4a / deferred / net delta. No commit.
