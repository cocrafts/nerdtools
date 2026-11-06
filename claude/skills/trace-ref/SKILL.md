---
name: trace-ref
description: Trace a metascript-recompiler bug or design question against its reference compiler — Nim for the core, typescript-go for the TypeScript-surface mechanisms Nim lacks, paper/ULTRALOCK.md for what crosses threads — to find the root cause and decide the fix. Answers "did we diverge from the reference's design, was it on purpose, and how do we get back?" Use when a bug in ~/metascript/recompiler needs root-cause tracing, before changing a compiler mechanism, or when the user types /trace-ref (formerly /trace-nim).
---

# Trace Ref

The metascript recompiler ports Nim's compiler core (memory management and move
semantics, transforms, codegen, generics, macros) under a TypeScript surface. When it
misbehaves, the fastest path to a **root** fix (not a workaround) is to trace the
mechanism against the real reference source and decide whether we diverged, whether
the divergence was intentional, and how to return to the reference model.

**Choose the reference by layer first**, because a session with no source to read falls
back on memory and reports a guess as a trace. The rule and its reasons are workspace
`~/metascript/CLAUDE.md` §Language behaviour; checkout paths are `paper/local.md`.

| layer | reference | role |
|---|---|---|
| core: DRC/ownership, transforms, codegen, generics and monomorphization, macros and the VM, overload ranking | Nim, `~/projects/nim/compiler/` | authority for the mechanism |
| TS-surface mechanisms Nim has no analog for: binder and flow narrowing, unions and literal types, TS-style inference, LSP | typescript-go, `~/projects/typescript-go/internal/` | authority for the mechanism; TS also decides what the author's code means |
| formatter: `msc fmt`, LSP formatting edits | Biome, `~/projects/biome/crates/biome_formatter`, `biome_js_formatter`, `biome_lsp`; typescript-go `internal/format/` read alongside | authority for the mechanism; Prettier (`~/projects/prettier`) shows the expected output |
| what crosses threads: custody on a move, views read on another thread, the pool and its waits, actors and pids, module state other threads read | `paper/ULTRALOCK.md` first, its law and its §6 reference index; Nim's parts there (`compiler/spawn.nim`, `lib/pure/concurrency/threadpool.nim`, `compiler/isolation_check.nim`, `--mm:atomicArc`, `--mm:yrc`) are the reference for what they cover | ULTRALOCK is binding law; a Nim counterpart's divergence gets a NIM-REF entry; `PARALOCK*.md` is history (§7 maps it) |
| what none of the above covers: borrowing, comptime, toolchain | Pony (`~/projects/ponyc`), Swift (`~/projects/swift`), Rust (`~/projects/rust`), Zig (`~/projects/zig`) | prior art, not authority |

When Nim and TS both have a mechanism for one concern, TS decides the behaviour the
author sees and Nim the mechanism underneath, so the core does not drift from Nim.
Within one thread (hooks, moves and sinks, destroy injection, cursor and `lent`, the cycle
collector's own work) the core stays on Nim even inside an async or actor program.

**Divergence log:** `~/metascript/recompiler/paper/NIM-REF.md` holds every divergence,
Nim's and typescript-go's alike: an entry whose mechanism comes from typescript-go cites
it in a `TS:` field. `paper/TSG-REF.md` is a review register of proposals, not where a
divergence goes. NIM-REF §0: a difference is a divergence only when the observable result
differs.

## Hard rules

- **TS → reference → Safety guides the decision, not a printed checklist.** Follow
  `~/metascript/CLAUDE.md` §Language behaviour and §Reporting: establish whether the TS
  author keeps their meaning on the reference's mechanism. Explain a divergence when one exists;
  distinguish missing reference coverage from a proven safety conflict. If TS behaviour cannot
  be made safe, state what the author loses and ask for the decision. Lead the report with the
  app-visible conclusion, then the reference and measured proof, because finding the algorithm
  alone does not tell the author what they keep or lose.
- **NEW MECHANISM is a finding the trace proves, never a label for an idea** — apply the
  workspace §Language behaviour rule of that name (split into parts, read Nim and
  typescript-go per part, a port or an emit-only change is no mechanism, "not traced yet"
  until read). Raise a proven one before implementation: it asks the person for scope.
- **Empirical, never recall.** READ the reference source and our `.ms` source this session
  and name the reference commit (`git -C <checkout> log -1 --format=%h`), because memory is
  how a guess gets reported as a trace. Confirm by emitting C (`msc build f.ms --emit=c`).
- **The reference is authority for the ALGORITHM, not the representation** (NIM-REF AN-4,
  §0): AST shape and type representation may differ; the algorithm and invariant follow it.
- **A model has to be earned by runtime prerequisites.** Before proposing "adopt the
  reference's model," confirm the runtime supports it (e.g. Nim's "always emit `=destroy`,
  moved values are zeroed, destroy-on-zero is a no-op" works only because `msDecref` is
  NULL-guarded — verify in `runtime/core/system.h`).
- **The fix is a verdict, not a menu.** The output is ONE verdict (SAME /
  DIVERGE-INTENTIONAL / DIVERGE-UNINTENTIONAL / DIVERGE-INCOMPLETE) and, when it is
  UNINTENTIONAL/INCOMPLETE, ONE fix: **follow the reference**, because a further divergence is
  the anti-goal, not a peer option. Surface a choice ONLY when (a) two paths are BOTH
  reference-faithful, or (b) a recorded DIVERGE-INTENTIONAL constraint applies and you choose
  *within* it. The hours a fix costs never decide between options (workspace §Language
  behaviour); a runtime cost counts only when measured.
- **A task-tracker's suggested fix does NOT override the trace.** BUGS.md, cards and handoff
  notes may propose a fix (often a convenient reuse of an existing mechanism). Re-derive the
  verdict from the reference source + NIM-REF this session; reject a proposal that diverges
  without a recorded reason, and say why.
- **Verify in your own worktree.** Other sessions work in parallel: list them with
  `~/nerdtools/claude/tools/wt.sh ls` (worktrees under `~/metascript/.wt/`, cards at
  `~/metascript/.wt/<name>.md`) and check a card's `Neighbours`. Probe in `/tmp` or your
  worktree; never edit another worktree or the main checkout, which only receives lands.

## Workflow

### 1. Reproduce carefully — understand the BEHAVIOR before opening any reference source
Do not read the reference, do not read our analyzer, do not theorize. First make the bug
happen on demand and pin exactly *when* it happens, because tracing a mechanism that isn't
the one firing burns hours.

1. **Build a HEAD-matched compiler.** A red can be a bug already fixed in the tree but not
   in the installed `msc`. A candidate build is a heavy job: run it with the checks that use
   it through `~/metascript/.gate-host/run-remote.sh` (workspace §Worktrees). Keep the object
   cache; suspect a stale cache only for a named stale-cache symptom. If the repro doesn't
   survive on a fresh candidate, there is nothing to trace.
2. **Minimal repro that RUNS, not just builds.** Print expected vs actual. Record both
   verbatim — the exact wrong value is evidence (e.g. `"noproc"` names which runtime path
   synthesized it).
3. **Isolation matrix — vary ONE axis at a time** until the trigger boundary is exact. Sync
   vs async; with vs without a suspend point; `throw` in the try body vs in the catch body;
   `const x = await f()` vs `x = await f()`; direct vs cross-function. Build the neighbours
   that WORK too — a fix that doesn't explain why the neighbour works is not a root cause.
4. **Memory and lifecycle run on native C under `--mm=drc`**, which always collects cycles;
   `--gc=drc|orc` is gone and refused (`src/compiler/options.ms`). Add a variant where the
   value is reachable from a cycle, because the collector path is part of the one mode, and
   a JS or Raiser run alone never exercises DRC.
5. **Gate:** you can state the boundary in ONE falsifiable sentence — "A works, A+B fails" —
   and predict a case you haven't run yet. Only then continue.

Write the repro set down (paths + one-line outputs). Later steps refer back to it, and it
becomes the pin (with a variant on a second axis, workspace §Compiler boundary) or the guard
in `nim-guard`.

### 2. Pin the mechanism (what actually happens)
Emit C for the failing case AND for the nearest passing neighbour, then diff the emitted ops
on each control-flow path (`paper/DRC-PROBE.md`). State the bug as a violated **invariant**,
not a symptom (e.g. "destroy is skipped on a path where the value was NOT moved" — a
path-sensitive property stored path-insensitively).

### 3. Find the reference's analogous mechanism
Use the reference the layer table selects. In Nim: `injectdestructors.nim` (moves, scope
destroys, `processScope`, `moveOrCopy`, `destructiveMoveVar`, `pVarTopLevel`), `dfa.nim`
(`constructCfg`, last-read/last-use), `liftdestructors.nim` (`=destroy`/`=copy`/`=sink`/
`=wasMoved` bodies). In typescript-go: `internal/binder/` (flow graph),
`internal/checker/flow.go` (narrowing, loop labels, assignment types),
`internal/checker/checker.go` (types, inference, relations), `internal/ls/`. Across threads:
the ULTRALOCK requirement row and its §6 anchors. Read how the reference achieves the
invariant and **where** (compile-time decision vs runtime behaviour vs a separate pass). When
no reference covers the layer, say so and read the prior-art repos as evidence; whether that
makes a NEW MECHANISM is decided by the hard rule above, not by where the idea came from.

### 4. Diff — where do we deviate?
Line up the reference's mechanism against ours. Name the exact extra/missing step. Common
divergence shapes (Nim core):
- We added a **compile-time elision** Nim does at **runtime** (or in a later opt).
- We store a **path-sensitive** fact in a **path-insensitive** structure.
- Our **pending-flush / statement-boundary** model reorders vs Nim's explicit
  `sink; wasMoved` sequencing.

### 5. Classify the divergence — intentional or not
Grep `paper/NIM-REF.md` (and the ULTRALOCK row for a cross-thread part):
- **Listed DIVERGE-INTENTIONAL** → read the rationale. The fix must RESPECT it: design inside
  that constraint. If the rationale no longer holds, say so and flag it for a decision.
- **Listed SAME but the code clearly isn't** → the smoking gun: an undocumented workaround
  crept in. Return to the reference.
- **Not listed** → compare observable results first, because NIM-REF §0 counts only a
  different result as a divergence. Same result on every backend → no divergence: no entry,
  no refactor. Different result → unintentional: return to the reference's model.
- **A new entry** is written only when the divergence is forced: the reference's behaviour
  breaks the safety rule, or the TS meaning cannot be carried on its mechanism. Show that
  evidence and write it in NIM-REF (a typescript-go mechanism cites it in `TS:`) after the
  person approves. A difference seen only where a type lies is a bug for an inbox card,
  because an entry reads as permission to every later session.

### 6. Produce the report
- **App-visible conclusion and recommendation first**, following `~/metascript/CLAUDE.md`
  §Reporting. The items below are supporting evidence: include what the decision needs in
  concise prose or bullets, not a mandatory sequence of labels.
- **The repro set** (step 1): the boundary sentence + the passing neighbours that bound it.
- **The invariant** violated + empirical evidence (emitted C, predictions that held).
- **The exact divergence** (reference file:line, with its commit, vs our fn:line).
- **Verdict:** intentional (with rationale), unintentional, or no divergence (same result),
  with the NIM-REF evidence.
- **Return-to-reference plan**, staged if risky: a minimal step that fixes the bug by moving
  toward the reference, then the full alignment (delete the non-reference mechanism).
- **Runtime prerequisite check** (does the runtime already support the reference's model?).
- **Verification plan** from the edit loop (`src/test/CLAUDE.md` §Edit loop): the pin red on
  the old compiler and green on the candidate in its backend variants, plus the check that
  guards the adjacent hard-won fix (self-consume, ASan cases, leak delta).

## Anti-patterns
- **Opening reference source before the trigger boundary is pinned.** Reading
  `injectdestructors.nim` to figure out what the bug *probably* is matches Nim against a
  guessed mechanism. Step 1 first.
- **Trusting a repro that was never run**, only built — or one built on the installed `msc`
  with a warm cache. Both routinely produce phantom bugs.
- **Framing the fix as "Option A vs Option B" when one option follows the reference and the
  other invents a new divergence.** The reference wins unless NIM-REF records an INTENTIONAL
  reason not to; picking the faithful path out of a lineup is the trace's job, not the user's.
- Refactoring toward the reference when every program already keeps its result.
- Inheriting a divergence because a task-tracker note recommended it.
- Proposing a special-case that pattern-matches the failing idiom (symptom patch) instead of
  restoring the invariant.
- Inventing a second branch-aware mechanism when the reference (and our own `optimize.ms`)
  already has the branch-awareness in one place.
- Declaring "root fix" before the predictions and the runtime prerequisite are confirmed.
- Editing shared analyzer files while another worktree holds them (`wt.sh ls`, then
  `git diff main...wt/<other> -- <paths>`).
