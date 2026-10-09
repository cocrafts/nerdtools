---
name: trace-ref
description: Trace a metascript-recompiler bug or design question against its reference compiler — Nim for the core, typescript-go for the TypeScript-surface mechanisms Nim lacks — to find the root cause and decide the fix. Answers "did we diverge from the reference's design, was it on purpose, and how do we get back?" Use when a bug in ~/metascript/recompiler needs root-cause tracing, before changing a compiler mechanism, or when the user types /trace-ref (formerly /trace-nim).
---

# Trace Ref

The metascript recompiler ports Nim's compiler core (memory management and move
semantics, transforms, codegen, generics, macros) under a TypeScript surface. When it
misbehaves, the fastest path to a **root** fix (not a workaround) is to trace the
mechanism against the real reference source and decide whether we diverged, whether
the divergence was intentional, and how to return to the reference model.

**Choose the reference by layer first**, because a session with no source to read falls
back on memory and reports a guess as a trace:

| layer | reference | role |
|---|---|---|
| core: DRC/ownership, transforms, codegen, generics and monomorphization, macros and the VM, overload ranking | Nim, `~/projects/nim/compiler/` | authority for the mechanism |
| TS-surface mechanisms Nim has no analog for: binder and flow narrowing, unions and literal types, TS-style inference, LSP | typescript-go, `~/projects/typescript-go/internal/` | authority for the mechanism; TS also decides what the author's code means |
| concerns neither covers: actors and capabilities, sendability, borrowing, comptime, toolchain | Pony (`~/projects/ponyc`), Swift (`~/projects/swift`), Rust (`~/projects/rust`), Zig (`~/projects/zig`) | prior art only; adopting one is still NEW MECHANISM |

When Nim and TS both have a mechanism for one concern, TS decides the behaviour the
author sees and Nim the mechanism underneath; typescript-go becomes the mechanism only
where Nim has none, so the core does not drift from Nim. **NEW MECHANISM** means
something MetaScript has that neither Nim nor typescript-go has.

**Divergence log:** `~/metascript/recompiler/paper/NIM-REF.md` — where intentional
divergences are (or should be) recorded, with DIVERGE-INTENTIONAL / SAME verdicts; an
entry whose mechanism comes from typescript-go cites it in a `TS:` field.

## Hard rules

- **TS → reference → Safety guides the decision, not a printed checklist.** Follow
  `~/metascript/CLAUDE.md` §Language behaviour and §Reporting: establish whether the TS
  author keeps their meaning on the reference's mechanism. Explain a divergence when one exists;
  distinguish missing reference coverage from a proven safety conflict. An extension is
  **NEW MECHANISM**, raised before implementation with what it adds and can regress.
  If TS behaviour cannot be made safe, state what the author loses and ask for the decision.
  Lead the report with the app-visible conclusion, then the relevant reference and measured
  proof, because finding the algorithm alone does not tell the author what they keep or lose.
- **Empirical, never recall.** READ the actual reference source (Nim `.nim`, typescript-go
  `.go`) and the actual recompiler `.ms` source this session. Do not trust memory of
  "how Nim works" or "how TS does it"; name the reference commit you read
  (`git -C <checkout> log -1 --format=%h`).
  Confirm behavior by emitting C (`msc build f.ms --gc=drc --emit=c --output=f.c`,
  read `out/debug/Z...c`) — ground truth beats theory.
- **The reference is authority for the ALGORITHM, not the representation.** NIM-REF AN-4 (⛔ FINAL DECISION):
  Q1 (AST node shape, e.g. `nkStmtListExpr`) may intentionally differ; Q2 (the
  algorithm / invariant) should follow the reference. Don't "fix" an intentional
  representation divergence.
- **A model has to be earned by runtime prerequisites.** Before proposing "adopt
  Nim's model," confirm the runtime supports it (e.g. Nim's "always emit
  `=destroy`, moved values are zeroed, destroy-on-zero is a no-op" only works
  because `msDecref` is NULL-guarded — verify in `runtime/core/system.h`).
- **The fix is a verdict, not a menu.** The workflow's output is ONE verdict
  (SAME / DIVERGE-INTENTIONAL / DIVERGE-UNINTENTIONAL / DIVERGE-INCOMPLETE) and,
  when it is UNINTENTIONAL/INCOMPLETE, ONE fix: **follow the reference.** Never hand the user
  a choice between "the reference-faithful fix" and "a self-invented shortcut that
  diverges further" — a further divergence is the anti-goal, not a peer option.
  Surface a genuine choice ONLY when (a) two candidate paths are BOTH reference-faithful,
  or (b) a documented DIVERGE-INTENTIONAL constraint genuinely applies and you are
  choosing *within* it. Check whether the reference's mechanism is followable FIRST; if it is
  and NIM-REF gives no intentional reason to diverge, there is nothing to ask.
- **A task-tracker's suggested fix does NOT override the reference trace.** BUGS.md /
  handoff notes may propose a fix (often a convenient reuse of an existing
  mechanism). Re-derive the verdict from the reference source + NIM-REF this session; if the
  proposed fix diverges from the reference without a documented reason, reject it and say why.
  A prior note recommending a divergence is not authority.
- **Don't touch the live tree to verify.** The recompiler often has a parallel
  session (check `git status`, `.claude/worktrees/`). Verify on a `/tmp` copy or
  emit-C only until green; stage in the real tree only after consensus.

## Workflow

### 1. Reproduce carefully — understand the BEHAVIOR before opening any reference source
Do not read the reference, do not read our analyzer, do not theorize. First make the bug
happen on demand and pin exactly *when* it happens. Skipping this is how sessions
burn hours tracing a mechanism that isn't the one firing.

1. **Build a HEAD-matched compiler.** A red can be a bug already fixed in the tree
   but not in the installed `msc`. Keep the object cache (the repository forbids
   wiping it); suspect a stale cache only for a named stale-cache symptom. If the
   repro doesn't survive on a freshly built binary, there is nothing to trace.
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

### 3. Find the reference's analogous mechanism
Use the reference the layer table selects. In Nim: `injectdestructors.nim` (moves, scope
destroys, `processScope`, `moveOrCopy`, `destructiveMoveVar`, `pVarTopLevel`),
`dfa.nim` (`constructCfg`, last-read/last-use), `liftdestructors.nim` (`=destroy`
/`=copy`/`=sink`/`=wasMoved` bodies). In typescript-go: `internal/binder/` (flow graph), `internal/checker/flow.go`
(narrowing queries, loop labels, assignment types), `internal/checker/checker.go`
(types, inference, relations), `internal/ls/` (language service). Read how the
reference achieves the invariant and **where** (compile-time decision vs runtime
behavior vs a separate pass). When the layer has no reference, say so and read the
prior-art repos for evidence; a mechanism taken from them is NEW MECHANISM.

### 4. Diff — where do we deviate?
Line up the reference's mechanism against ours. Name the exact extra/missing step. Common
divergence shapes (Nim core):
- We added a **compile-time elision** Nim does at **runtime** (or in a later opt).
- We store a **path-sensitive** fact in a **path-insensitive** structure.
- Our **pending-flush / statement-boundary** model reorders vs Nim's explicit
  `sink; wasMoved` sequencing.

### 5. Classify the divergence — intentional or not
Grep `paper/NIM-REF.md` for the mechanism:
- **Listed DIVERGE-INTENTIONAL** → read the rationale. The fix must RESPECT the
  divergence. Trace deeper WHY it exists and design a fix inside that constraint.
  If the rationale no longer holds, say so explicitly and flag for a decision.
- **Listed SAME / not listed** → the divergence is **unintentional**. The fix is to
  **refactor back to the reference's model.** (If NIM-REF.md claims SAME but the code
  clearly isn't, that's the smoking gun — an undocumented workaround crept in.)

### 6. Produce the report
- **App-visible conclusion and recommendation first**, following `~/metascript/CLAUDE.md`
  §Reporting. The items below are supporting evidence: include what the decision needs in
  concise prose or bullets, not a mandatory sequence of labels.
- **The repro set** (step 1): the trigger boundary sentence + the passing
  neighbours that bound it.
- **The invariant** violated + empirical evidence (emitted C, falsifiable
  predictions that held).
- **The exact divergence** (reference file:line, with its commit, vs our fn:line).
- **Verdict:** intentional (with rationale) or unintentional, with the NIM-REF.md
  evidence.
- **Return-to-reference plan**, staged if risky: a minimal step that fixes the bug by
  moving toward the reference, then the full alignment (delete the non-reference mechanism).
- **Runtime prerequisite check** (does the runtime already support the reference's model?).
- **Verification plan:** rebuild `msc`, re-emit the repro C, run the DRC/native
  test that guards the adjacent hard-won fix (e.g. self-consume/ASAN cases), and
  the engine leak-delta — before staging.

## Anti-patterns
- **Opening reference source before the trigger boundary is pinned.** Reading
  `injectdestructors.nim` to figure out what the bug *probably* is inverts the
  workflow: you end up matching Nim against a guessed mechanism. Step 1 first.
- **Trusting a repro that was never run**, only built — or one built on the
  installed `msc` with a warm cache. Both routinely produce phantom bugs.
- **Framing the fix as "Option A vs Option B" when one option follows the reference and the
  other invents a new divergence.** If you catch yourself weighing "reuse the
  existing X-promotion machinery" against "do what the reference does," stop — the reference wins unless
  NIM-REF documents an INTENTIONAL reason not to. The user should never have to pick
  the reference-faithful path out of a lineup; that's the trace's job.
- Inheriting a divergence because a task-tracker note recommended it, instead of
  re-deriving the verdict from the reference source this session.
- Proposing a special-case that pattern-matches the failing idiom (symptom patch)
  instead of restoring the invariant.
- Inventing a second branch-aware mechanism when the reference (and our own `optimize.ms`)
  already has the branch-awareness in one place.
- Declaring "root fix" before the falsifiable predictions and the runtime
  prerequisite are confirmed empirically.
- Editing shared analyzer files while a parallel session/worktree holds them.
