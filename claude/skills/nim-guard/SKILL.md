---
name: nim-guard
description: Add a regression guard that proves a Nim-derived lifecycle invariant goes red when broken and green when restored. Use for proactive DRC, ARC, ORC, move, copy, sink, or destructor invariants in metascript-recompiler.
---

# Nim Guard

The metascript recompiler ports Nim's memory-management + move semantics
(ARC/ORC `injectdestructors`, `dfa`, `liftdestructors`, `sempass2`). Over time,
refactors **silently drift** from the Nim model — a decref path forgets to gate
a destructor on last-ref, a move stops zeroing, a `=sink` degrades into a
`=copy`. `/trace-nim` catches this **reactively** (after a crash). `/nim-guard`
is the **proactive** half: it bakes a test into the suite that goes RED the
moment a refactor breaks a Nim-derived lifecycle invariant — at CI, not via a
lucky production crash weeks later.

Use `/nim-guard <fixed-bug | invariant | subsystem>` to add such a guard.

**Guards live in:** `~/metascript/recompiler/src/test/guard/` (`run.sh` + probes + README).
**Nim source:** `~/projects/nim/compiler/` (algorithm) and `~/projects/nim/tests/arc/` (Nim's OWN guard methodology — counter-instrumented `=destroy`/`=copy`/`=sink` + exact-count asserts, e.g. `tarcmisc.nim`; structural `--expandArc` IR pins, e.g. `topt_wasmoved_destroy_pairs.nim`).
**Divergence log:** `~/metascript/recompiler/paper/NIM-REF.md`.

## The mechanism (already built — do not reinvent)

The **DRC ledger** (`runtime/drc.c`, `runtime/drc.h`), enabled with
`-DMS_DRC_LEDGER` (off by default → zero cost in normal builds), present in both
`--gc=drc` and `--gc=orc`:

- Every last-ref `destroyFn` dispatch routes through `MS_DESTROY_DISPATCH`
  (`drc.h`). The ledger **aborts on the 2nd finalize of a live pointer** —
  `NIM-GUARD LEDGER: DOUBLE-DESTROY of <type>` — the name-agnostic primary
  signal that some decref path finalized an object that still had an owner.
- Alloc/destroy are counted per type and dumped at exit:
  `LEDGER <type> alloc=A destroy=D`. An imbalance is a leak (destroy<alloc) or a
  double-finalize (destroy>alloc).

`run.sh` builds each probe with the ledger (both gc modes) and asserts: clean
exit, no `DOUBLE-DESTROY`, and any declared `// GUARD-BALANCE <Type>` holds.

This is the behavioral tier — it maps directly onto Nim's ARC test suite (count
lifecycle events, assert exact counts). It catches the class that keeps biting:
runtime RC-accounting drift invisible to output-only unit tests (a program can
print the right answer and still double-free intermittently).

## Hard rules

- **A guard must be PROVEN to go red.** Before trusting/committing it, build with
  the invariant violated (revert the fix, or inject the divergence) and show the
  guard fails; then show it green on HEAD. A guard that cannot fail is worthless.
  This is non-negotiable — demonstrate the red empirically, never assume it.
- **Assert the INVARIANT, never the representation.** Count finalizes / moves;
  never diff emitted-C bytes or assert the rc-convention. The guard must survive
  legitimate divergences (named-field AST, `rc=0` sole-owner, `msString`) and
  fire only on a real invariant break. Prefer the name-agnostic double-destroy
  abort; use `GUARD-BALANCE <MangledType>` only for leak guards, and know the
  mangled name is brittle under transform refactors.
- **Every guard cites Nim + NIM-REF.** The probe header states the invariant, the
  Nim source (proc / test), the NIM-REF row + verdict (SAME vs
  DIVERGE-INTENTIONAL), and a "RED MEANS … run /trace-nim on the named type"
  line. A red guard is a `/trace-nim` entry point, not a bare X.
- **Make timing windows deterministic.** Concurrency/lifecycle races (spawn env,
  completion drain, actor suspend) surface intermittently. Amplify with high
  iteration so the bad interleaving executes every run — do NOT rely on a lucky
  schedule, and do NOT reach for ASAN (it slows workers and masks the very
  timing window you are trying to pin).
- **Guard intentional divergences too, inversely.** For a DIVERGE-INTENTIONAL row
  (e.g. `rc=0` sole-owner, unmutated params → `const T*`), a guard should assert
  the divergence STILL HOLDS, so a refactor that "corrects toward Nim" and breaks
  it also goes red.
- **Don't touch the live tree to prove red.** Toggle the fix in the deployed
  sandbox (`~/.metascript/runtime/...`) or a `/tmp` copy to demonstrate the red,
  then restore.

## Workflow

1. **Pin the invariant.** State it as a violated property, not a symptom
   ("a destructor ran on a value that still had an owner"). If the root cause
   isn't already known, run `/trace-nim` first — nim-guard freezes a verdict that
   trace-nim produced.
2. **Find Nim's analogue + its own guard.** Locate the Nim proc
   (`injectdestructors` / `liftdestructors` / `dfa`) and, if one exists, the Nim
   test that guards it (`tests/arc/*`). Read how Nim asserts it (counters /
   expandArc) and confirm the NIM-REF verdict.
3. **Write the probe** in `src/test/guard/`, header citing Nim + NIM-REF + the
   RED-MEANS line. Shape it so the violation is observable to the ledger
   (double-destroy for finalize-twice; per-type balance for leaks) and
   deterministic (high iteration; the minimal capture/branch shape that triggers
   it — recall the just-fixed bug needed BOTH a loop-local capture AND a shared
   heap payload).
4. **Prove red, then green.** Toggle the invariant broken in the deployed
   sandbox → `run.sh` (or a direct `-DMS_DRC_LEDGER` build) must FAIL; restore →
   must pass, both `--gc=drc` and `--gc=orc`.
5. **Register.** The probe is auto-discovered by `run.sh`. If the invariant needs
   an observation the ledger can't make (e.g. exact op PLACEMENT rather than
   lifecycle balance), note it in the header as a known gap — a structural
   (`--expandArc`-style IR) tier is intentionally NOT built yet; only add it when
   a real drift slips past the behavioral ledger (a wrong emit on a path the
   probe didn't execute).

## Anti-patterns

- Committing a guard without demonstrating the red — the single worst failure
  mode; a green-only "guard" gives false confidence and guards nothing.
- Asserting emitted-C bytes or a mangled name as the CORE signal — brittle;
  breaks on legitimate refactors, trains people to delete the guard.
- Reaching for ASAN or relying on run-to-run flakiness instead of amplifying the
  window to determinism.
- Writing a guard for an invariant you have not traced to a Nim source + NIM-REF
  verdict — you may be pinning a bug as if it were the spec.
- Building the structural/IR tier speculatively before the behavioral ledger has
  demonstrably missed a real drift.

Base directory for this skill: `~/.claude/skills/nim-guard`
