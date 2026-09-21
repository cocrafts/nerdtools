# Comments in code — the practice behind the global rule

The global CLAUDE.md carries one line pointing here; this file is the whole law —
taxonomy, test, worked examples, enforcement. Relaxed from absolute zero on 2026-09-21;
see "Why the exception exists" at the end.

## The rule in one line

Write a comment only when the code cannot carry the fact, a test cannot pin it, and a
future edit would be wrong without it.

## Taxonomy

| kind | example | verdict |
|---|---|---|
| WHAT — restates the code | `// increment i`, `// loop over the tokens` | dead |
| narrative — references the task | `// added for login flow (issue #123)` | dead; commit message territory |
| tutorial — teaches the language | `// const bindings cannot be reassigned` | dead; training-corpus habit, the dominant AI failure mode |
| design-prose — justifies the change being made | a 4-line block above a function explaining the new approach | dead; the diff and commit review carry it |
| WHY-external — a fact from outside the code | ABI bug, benchmark result, spec clause | **legal**, if it passes the test |

## The three-part test — all three must hold

1. **Not derivable from the code.** A reader of the code alone cannot get there.
2. **Not encodable.** No name, test, or assertion can carry it. Try those first:
   `dontOptimizeTailCall` is a name; a benchmark regression test is a test; an
   `assert` in the suite is an assertion. Only when all three fail is prose left.
3. **Load-bearing for a future edit.** Without it, someone reorders, "cleans up", or
   optimizes past the constraint and breaks it.

Form: 2–3 lines max, imperative mood, names the external authority (which ABI, which
benchmark, which clause of which spec). No narration, no task references, no emojis.
The canonical anti-pattern is 4+ lines of justification on a 2-line change — the diff
and the commit review carry that, not the file.

## Worked examples

LEGAL — external ABI fact; not testable without the affected box; blocks the obvious
"tidy this into a variadic" edit:

```c
// aarch64-windows-gnu reads variadic args 4+ of 16-byte structs from misaligned
// slots (AAPCS64 vs MS variadic ABI): pass by pointer, never through ...
```

LEGAL — benchmark fact that inverts the obvious optimization:

```c
// branchless form measured 12% slower here (M3 Max, 2026-03 corpus bench); do not "fix"
```

ILLEGAL — fails test 1 (the loop says it) and test 3 (no future edit depends on it):

```ms
// iterate over the tokens and append them
for t of tokens { out.append(t) }
```

ILLEGAL — a real constraint written in a dead form: task reference plus a TODO promise.
The fact belongs in the commit and the arc card, not the code:

```ms
// HACK: workaround for the sync bug — TODO clean up later
```

## Existing comments during an edit

The rule governs adding. When your edit makes an existing comment wrong, fix or remove
that one comment — leaving it stale is worse than both options. Do not sweep a file
clean of pre-existing comments as a side effect; that diff noise is not yours to make.

## The hook

`~/nerdtools/claude/hooks/comment-guard.sh`, wired in `~/.claude/settings.json`
(PostToolUse, matcher `Edit|Write`). For each edit it scans `new_string` (and the whole
content of newly created files) for added comment lines, mapped by extension:
`//` and `/*` openers for the C-style family, `#` for the script family (shebangs
exempt), `--` for sql/lua/haskell. Markdown and unknown extensions are exempt;
docstrings are deliberately not flagged — they are API surface, not inline comments.
On a hit it exits 2 with the offending lines on stderr, which Claude Code feeds back
to the model.

When flagged: delete the comment, or check it against the three-part test and keep it.
The hook is a reminder, not a court — but never argue with it or edit around it.

Scope: both agents, one law. Claude Code wires the script in `~/.claude/settings.json`
(PostToolUse, matcher `Edit|Write`); omp execs the same script from
`~/nerdtools/omp/extensions/cc-compat.ts` (`tool_result` on write/edit, synthesizing the
hook payload — verified 2026-09-21 on both paths: new-file write and edit `+` rows).

## Why the exception exists (2026-09-21)

Absolute zero left no legal home for facts that cannot be encoded in code: compiler and
ABI bugs, benchmark-driven "do not optimize", spec citations. Community practice (HN
49078710 and lint-rule setups reported there) splits WHAT comments (always dead, the
tutorial-style noise LLMs emit by habit) from WHY comments (narrow, legal), and puts
enforcement in hooks or lint rather than prose — "often ignores instructions to not
leave obvious comments" is a reported failure mode of prose-only rules.
