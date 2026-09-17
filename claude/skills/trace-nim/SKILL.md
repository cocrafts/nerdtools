---
name: trace-nim
description: Trace a metascript-recompiler bug against the Nim reference compiler to find root cause and decide the fix. Answers "did we diverge from Nim's design, was it on purpose, and how do we get back?" Use when a bug in ~/metascript/recompiler (DRC/move/destroy/codegen/analyzer semantics) needs root-cause tracing, or the user types /trace-nim.
---

# Trace Nim

The metascript recompiler is a port of Nim's memory-management + move semantics
(ARC/ORC `injectdestructors`, `dfa`, `liftdestructors`, `sempass2`). When it
misbehaves, the fastest path to a **root** fix (not a workaround) is to trace the
mechanism against the real Nim source and decide whether we diverged, whether the
divergence was intentional, and how to return to the Nim model.

**Nim source:** `~/projects/nim/compiler/` — the ground truth for the ALGORITHM.
**Divergence log:** `~/metascript/recompiler/docs/NIM-REF.md` — where intentional
divergences are (or should be) recorded, with DIVERGE-INTENTIONAL / SAME verdicts.

## Hard rules

- **Empirical, never recall.** READ the actual Nim `.nim` source and the actual
  recompiler `.ms` source this session. Do not trust memory of "how Nim works."
  Confirm behavior by emitting C (`msc build f.ms --gc=drc --emit=c --output=f.c`,
  read `out/debug/Z...c`) — ground truth beats theory.
- **Nim is authority for the ALGORITHM, not the representation.** NIM-REF.md §3:
  Q1 (AST node shape, e.g. `nkStmtListExpr`) may intentionally differ; Q2 (the
  algorithm / invariant) should follow Nim. Don't "fix" an intentional
  representation divergence.
- **A model has to be earned by runtime prerequisites.** Before proposing "adopt
  Nim's model," confirm the runtime supports it (e.g. Nim's "always emit
  `=destroy`, moved values are zeroed, destroy-on-zero is a no-op" only works
  because `msDecref` is NULL-guarded — verify in `runtime/core/system.h`).
- **The fix is a verdict, not a menu.** The workflow's output is ONE verdict
  (SAME / DIVERGE-INTENTIONAL / DIVERGE-UNINTENTIONAL / DIVERGE-INCOMPLETE) and,
  when it is UNINTENTIONAL/INCOMPLETE, ONE fix: **follow Nim.** Never hand the user
  a choice between "the Nim-faithful fix" and "a self-invented shortcut that
  diverges further" — a further divergence is the anti-goal, not a peer option.
  Surface a genuine choice ONLY when (a) two candidate paths are BOTH Nim-faithful,
  or (b) a documented DIVERGE-INTENTIONAL constraint genuinely applies and you are
  choosing *within* it. Check whether Nim's mechanism is followable FIRST; if it is
  and NIM-REF gives no intentional reason to diverge, there is nothing to ask.
- **A task-tracker's suggested fix does NOT override the Nim trace.** BUGS.md /
  handoff notes may propose a fix (often a convenient reuse of an existing
  mechanism). Re-derive the verdict from Nim source + NIM-REF this session; if the
  proposed fix diverges from Nim without a documented reason, reject it and say why.
  A prior note recommending a divergence is not authority.
- **Don't touch the live tree to verify.** The recompiler often has a parallel
  session (check `git status`, `.claude/worktrees/`). Verify on a `/tmp` copy or
  emit-C only until green; stage in the real tree only after consensus.

## Workflow

### 1. Reproduce carefully — understand the BEHAVIOR before opening any Nim source
Do not read Nim, do not read our analyzer, do not theorize. First make the bug
happen on demand and pin exactly *when* it happens. Skipping this is how sessions
burn hours tracing a mechanism that isn't the one firing.

1. **Build a HEAD-matched compiler and `rm -rf out`.** A red can be pure stale
   cache, or a bug already fixed in the tree but not in the installed `msc`. If
   the repro doesn't survive a clean cache on a freshly built binary, there is
   nothing to trace.
2. **Minimal repro that RUNS, not just builds.** Print expected vs actual. Record
   both verbatim — the exact wrong value is evidence (e.g. `"noproc"` names which
   runtime path synthesized it).
3. **Isolation matrix — vary ONE axis at a time** until the trigger boundary is
   exact. Sync vs async; with vs without a suspend point; `throw` in the try body
   vs in the catch body; `const x = await f()` vs `x = await f()`; direct vs
   cross-function. Build the neighbours that WORK too — a fix that doesn't explain
   why the neighbour works is not a root cause.
4. **Check both GC modes** (`--gc=drc` and `--gc=orc`) when memory/lifecycle is
   involved, per [[feedback_drc_fix_verify_native_orc]].
5. **Gate:** you can state the boundary in ONE falsifiable sentence — "A works, A+B
   fails" — and you can predict a case you haven't run yet. Only then continue.

Write the repro set down (paths + one-line outputs). Steps 2-6 keep referring back
to it, and it becomes the guard in [[nim-guard]].

### 2. Pin the mechanism (what actually happens)
Emit C for the failing case AND for the nearest passing neighbour, then diff the
emitted ops on each control-flow path. State the bug as a violated **invariant**,
not a symptom (e.g. "destroy is skipped on a path where the value was NOT moved" —
a path-sensitive property stored path-insensitively).

### 3. Find Nim's analogous mechanism
Locate the corresponding proc in Nim: `injectdestructors.nim` (moves, scope
destroys, `processScope`, `moveOrCopy`, `destructiveMoveVar`, `pVarTopLevel`),
`dfa.nim` (`constructCfg`, last-read/last-use), `liftdestructors.nim` (`=destroy`
/`=copy`/`=sink`/`=wasMoved` bodies). Read how Nim achieves the invariant and
**where** (compile-time decision vs runtime behavior vs a separate optimization
pass).

### 4. Diff — where do we deviate?
Line up Nim's mechanism against ours. Name the exact extra/missing step. Common
divergence shapes:
- We added a **compile-time elision** Nim does at **runtime** (or in a later opt).
- We store a **path-sensitive** fact in a **path-insensitive** structure.
- Our **pending-flush / statement-boundary** model reorders vs Nim's explicit
  `sink; wasMoved` sequencing.

### 5. Classify the divergence — intentional or not
Grep/read `docs/NIM-REF.md` for the mechanism:
- **Listed DIVERGE-INTENTIONAL** → read the rationale. The fix must RESPECT the
  divergence. Trace deeper WHY it exists and design a fix inside that constraint.
  If the rationale no longer holds, say so explicitly and flag for a decision.
- **Listed SAME / not listed** → the divergence is **unintentional**. The fix is to
  **refactor back to Nim's model.** (If NIM-REF.md claims SAME but the code
  clearly isn't, that's the smoking gun — an undocumented workaround crept in.)

### 6. Produce the report
- **The repro set** (step 1): the trigger boundary sentence + the passing
  neighbours that bound it.
- **The invariant** violated + empirical evidence (emitted C, falsifiable
  predictions that held).
- **The exact divergence** (Nim proc:line vs our fn:line).
- **Verdict:** intentional (with rationale) or unintentional, with the NIM-REF.md
  evidence.
- **Return-to-Nim plan**, staged if risky: a minimal step that fixes the bug by
  moving toward Nim, then the full alignment (delete the non-Nim mechanism).
- **Runtime prerequisite check** (does the runtime already support Nim's model?).
- **Verification plan:** rebuild `msc`, re-emit the repro C, run the DRC/native
  test that guards the adjacent hard-won fix (e.g. self-consume/ASAN cases), and
  the engine leak-delta — before staging.

## Anti-patterns
- **Opening Nim source before the trigger boundary is pinned.** Reading
  `injectdestructors.nim` to figure out what the bug *probably* is inverts the
  workflow: you end up matching Nim against a guessed mechanism. Step 1 first.
- **Trusting a repro that was never run**, only built — or one built on the
  installed `msc` with a warm cache. Both routinely produce phantom bugs.
- **Framing the fix as "Option A vs Option B" when one option follows Nim and the
  other invents a new divergence.** If you catch yourself weighing "reuse the
  existing X-promotion machinery" against "do what Nim does," stop — Nim wins unless
  NIM-REF documents an INTENTIONAL reason not to. The user should never have to pick
  the Nim-faithful path out of a lineup; that's the trace's job.
- Inheriting a divergence because a task-tracker note recommended it, instead of
  re-deriving the verdict from Nim source this session.
- Proposing a special-case that pattern-matches the failing idiom (symptom patch)
  instead of restoring the invariant.
- Inventing a second branch-aware mechanism when Nim (and our own `optimize.ms`)
  already has the branch-awareness in one place.
- Declaring "root fix" before the falsifiable predictions and the runtime
  prerequisite are confirmed empirically.
- Editing shared analyzer files while a parallel session/worktree holds them.
