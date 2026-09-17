---
name: zone-issue-area
description: Classify a bug/issue by layer, phase, nature, severity, and fix risk — answers "what kind of bug is this and how dangerous is the fix?"
---

# Zone Issue Area

Classify any bug, issue, or unexpected behavior along 6 axes. Output a compact card — no prose, no investigation, just the classification.

## Input

The user describes a bug, pastes an error, or references an issue. If no issue context is available in conversation, ask for it.

## Classification Axes

### 1. Layer

Where in the stack does the bug live?

| Layer | Description |
|-------|-------------|
| **compiler** | Parser, checker, transforms, analyzer, codegen — the `.ms` → output pipeline |
| **runtime** | C runtime (`runtime/`), DRC, allocator, actor scheduler, async dispatcher |
| **stdlib** | `std/` libraries (collections, io, net, crypto, testing, etc.) |
| **tooling** | LSP, editor plugins, package manager, build scripts, CLI |
| **platform** | OS-specific, cross-compilation, target ABI issues |

### 2. Phase (compiler bugs only)

Which compiler phase owns the fix?

| Phase | Scope |
|-------|-------|
| **Phase 1 — Parse** | Tokenization, AST construction, syntax |
| **Phase 2 — Check** | Type inference, resolution, validation, symbol table |
| **Phase 3 — Transform** | Lowering, desugaring, lambda lifting, actor/async/generator transforms |
| **Phase 4 — Analyze** | DRC injection, destructor lifting, ownership analysis |
| **Phase 5 — Codegen** | C/JS emission (should be thin — if logic belongs earlier, say so) |

For non-compiler bugs, skip this axis.

### 3. Nature — What produced this bug?

Two sub-axes: **root cause** (why it exists) and **confidence** (how obvious is the fix).

#### Root cause

| Root cause | Description | Typical fix shape |
|------------|-------------|-------------------|
| **obvious-mistake** | Typo, copy-paste miss, placeholder never updated. Correct pattern is ≤10 lines away in the same file. | 1-3 line change, mechanical |
| **mistake** | Wrong logic but localized — wrong condition, missed branch, incorrect dispatch. Requires reading surrounding code to spot. | 5-20 line change, needs understanding of the function |
| **convention-violation** | Code works in isolation but breaks an internal contract (nodeType must be Promise<T>, DRC rc semantics, etc.). Author didn't know or forgot the convention. | Fix the call site + consider adding a guard/assert |
| **missing-path** | Feature path not implemented — not broken code, just absent code. Often shows as "works for type A, not for type B". | Add the missing branch/handler, model on existing ones |
| **design-mismatch** | The current architecture doesn't model this case — bolting on a fix would be a hack. Needs refactoring or a new abstraction. | Structural change, possibly multi-file |
| **interaction** | Two correct subsystems produce wrong result when combined. Neither is buggy alone. | Fix at the boundary, add integration contract |
| **regression** | Previously worked, broken by a recent change. | Revert or patch the breaking change |

#### Confidence — how sure are we about the fix?

| Confidence | Meaning |
|------------|---------|
| **certain** | Correct pattern exists in the same file/function, fix is mechanical copy |
| **high** | Root cause clear, fix shape known, just needs careful implementation |
| **medium** | Root cause identified but fix has multiple valid approaches — needs design choice |
| **low** | Symptom clear, root cause ambiguous — needs deeper investigation before fixing |

### 4. Severity

| Severity | Meaning |
|----------|---------|
| **blocker** | Prevents compilation or crashes at runtime for common patterns |
| **high** | Wrong output for real-world code, workaround exists but ugly |
| **medium** | Edge case, affects uncommon patterns |
| **low** | Cosmetic, suboptimal output, no functional impact |

### 5. Fix Risk — what could go wrong if you touch this?

| Risk | Meaning | Typical scenario |
|------|---------|------------------|
| **safe** | Isolated change, no downstream consumers depend on the current (broken) behavior. Self-compile + existing tests cover it. | Adding a missing branch that currently errors out |
| **low** | Small blast radius — change touches a shared helper but the new behavior is strictly more correct. Existing tests should catch regressions. | Fixing a type tag on a node constructor |
| **moderate** | Multiple call sites or phases depend on the behavior being changed. Need to audit downstream consumers. Self-compile is the real test. | Changing how a transform tags nodeType — affects await lowering, codegen, DRC |
| **high** | Touches a hot path or foundational convention (RC semantics, moveOrCopy, type resolution). Wrong fix can cascade into UAF, leak, or silent miscompile across unrelated code. | DRC inject changes, type compatibility changes, lambda lifting env shape |
| **dangerous** | Architectural change required — multi-file, multi-phase. Previous attempts at "quick fixes" in this area have caused regressions. | Rewriting ownership transfer convention, changing AST node shape |

Include a **1-line rationale** for the risk rating — what specifically could break.

### 6. Completeness — is this the whole story?

| Status | Meaning |
|--------|---------|
| **complete** | This is a standalone bug, fixing it resolves the symptom fully |
| **tip-of-iceberg** | Same root cause likely affects other code paths — audit recommended |
| **blocked** | Can't fix until another bug/dependency is resolved first |
| **chain** | Part of a bug family — list siblings |

## Output Format

Plain text, one line per axis. **No boxes, no tables, no ASCII frames** — those wrap ugly in narrow terminals. Just the label and the value. Keep the values themselves (`compiler`, `mistake`, `high`, etc.) as the canonical English tokens so they're greppable / copy-pasteable across bug trackers, but write the surrounding rationale, one-liner, and evidence in the **conversation's current language** (if the user is speaking Vietnamese, write Vietnamese; if English, write English; etc.).

Shape:

```
Zone — <one-liner ≤15 words>

Layer:        <layer>
Phase:        <phase or — for non-compiler>
Nature:       <root-cause> · confidence <confidence>
Severity:     <severity>
Fix risk:     <risk> — <1-line rationale in conversation language>
Completeness: <status> <siblings/blockers if any>

Fix site:     <file:line or module>
Evidence:     <2-3 short lines, conversation language>
```

Rules of thumb when emitting:
- Skip the `Phase:` line entirely for non-compiler bugs (don't print `—` for it).
- Wrap long rationales onto a new line indented under the label — never split a label/value pair with mid-line wrap artifacts.
- Don't pad with spaces to align columns. Single space after the colon is enough.

## Rules

- Do NOT investigate or fix — classify only.
- If unsure between two root causes, pick the one that determines where the fix goes and note the alternative in Evidence.
- If evidence is ambiguous, say "needs investigation" / "cần điều tra thêm" (match conversation language) on that axis rather than guessing.
- The output should be copy-pasteable into a bug tracker — but humans read it first, so readability > rigid framing.
- Fix risk MUST include a rationale — naked "moderate" is not allowed.
- Match the conversation language for prose. Keep the axis tokens themselves in English (they're tags, not narration).
