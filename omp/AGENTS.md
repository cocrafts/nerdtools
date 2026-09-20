@~/.claude/CLAUDE.md

# Adapters — omp only

Everything above is `~/nerdtools/claude/CLAUDE.md`, the shared config, loaded verbatim.
It names no agent on purpose: Claude Code owns it and never changes for anyone else.
What follows is what omp has to do by hand, because it cannot read Claude Code's wiring.

This file shadows `~/.claude/CLAUDE.md` at user scope — omp keeps one user context file
and this one outranks it. The import above is what puts the shared config back. If the
shared rules are ever missing from a session, that line is why; omp leaves an unreadable
`@` token as plain text and reports nothing.

## Memory is Claude Code's store

Memory for a working directory lives in `~/.claude/projects/<slug>/memory/`. The slug is
the directory's absolute path with every character that is not a letter or a digit
replaced by `-`, so `C:\Users\metacraft\metascript\compiler` becomes
`C--Users-metacraft-metascript-compiler`. Worktrees are separate paths and get separate
stores.

Read `MEMORY.md` in that directory at the start of a session; it is the index, one line
per memory, `- [Title](file.md) — hook`. Write a new memory as its own file beside it and
add the pointer line:

```markdown
---
name: <short-kebab-case-slug>
description: <one line, used to judge relevance later>
metadata:
  type: user | feedback | project | reference
---

<one fact. For feedback and project, follow with **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].>
```

`user` is who the person is, `feedback` is guidance on how to work and why, `project` is
ongoing work with relative dates resolved to absolute ones, `reference` is a pointer to
something external. Update the file that already covers a fact rather than adding a
second. Do not record what the repo already shows — code structure, git history, a
CLAUDE.md.

Claude Code writes the same files in the same shape with its own ordinary file tools, so
both agents share one store. Keep `memory.backend` off; a backend here would fork it.

## A subdirectory may carry its own CLAUDE.md

Claude Code loads a `CLAUDE.md` from the directory of a file it touches. omp only walks
up from the working directory, so a `CLAUDE.md` below it never loads on its own. Repos
here put real rules in those files, and a repo can hold a dozen of them.

Before editing a file, check its directory and each directory above it up to the
repository root for a `CLAUDE.md`, and read the ones you find.
