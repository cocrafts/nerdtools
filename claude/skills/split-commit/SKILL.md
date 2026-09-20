---
name: split-commit
description: Commit pending work as SMALL logical commits with short conventional messages, no body, no attribution. In a shared checkout every commit is constructed from the session's enumerated edits in a private index seeded from a captured parent, published compare-and-swap. Use when the user says /split-commit or asks to split pending work into small commits.
---

# split-commit — Son's rules for small commits

Runs when the user asked to commit, or the project's CLAUDE.md lets the agent
commit on its own (the `~/metascript` workspace does); elsewhere never volunteer
commits.

**Two jobs, in order: (1) commit ONLY what this session wrote, (2) split into
small logical commits.** Job 1 outranks job 2 — a clean split carrying a peer's
WIP is worse than a slightly-large commit of exactly your own work. A commit is
a tuple you construct — parent captured by hash, tree built from the session's
edit log, message — never a filter over current state, so peer work cannot ride
along by construction. Bans appear only where they override a default of the
tool or model (attribution footers, commit bodies, volunteering a push) or block
a destructive action; anything else becomes a construction step, not a rule.

## Message format — HARD RULES

- `type(scope): subject` — conventional commits. Types: feat, fix, refactor, docs, test, chore, perf, ci, build.
- **Short subject. NO body, NO description, NO bullet list.** One `-m` only.
- **NO attribution footer** (no Co-Authored-By / Generated-with — attribution is disabled globally in his settings).
- Match the repo's scope convention first: `git log --oneline -15`.

In `~/metascript` these are enforced by `.githooks/commit-msg` (via
`core.hooksPath`, inherited by linked worktrees): a non-conforming subject, any
body, or attribution makes a red commit. `Merge`, `Revert`, `fixup!`, `squash!`
are exempt.

## Which path — decided by the tree, not by judgment

```sh
git rev-parse --show-toplevel; git worktree list | head -1
```

| The tree this session works in | Path |
|---|---|
| Own linked worktree on `wt/<name>` (`tools/wt.sh new`, `git worktree add`) — one writer by construction | Plain commits: `git status --short` once for junk, `git add <explicit files>`, `git commit`. The `commit-msg` hook runs; nothing can race you. |
| Shared tree — nerdtools, anything reached through a `~/.claude` symlink, a metascript main checkout taking a no-arc edit, a sibling repo's checkout | The procedure below. |
| In doubt | The procedure — safe everywhere; the plain path is safe only alone. |

Running the procedure in an own worktree is safe but buys nothing:
`commit-tree` bypasses the `commit-msg` hook, and a leaked `GIT_INDEX_FILE`
poisons the shell's later git calls. Playing safe means defaulting to the
procedure when the tree might be shared, not abolishing the plain path.

Landing an own worktree's branch on `main` is the repo's step, not this
skill's: recompiler `tools/wt.sh land`; the other `~/metascript` repos
`git rebase main`, gate, `merge --ff-only`. Never copy files into the main
checkout to commit them there; no push or pull between checkouts.

A sibling repo's file edited from this session is committed in that repo's
shared tree (the procedure) before the session isolates itself in a worktree;
afterwards git outside the worktree is refused and the edit is named in
`~/metascript/.inbox/<repo>/<yyyy-mm-dd>-<slug>.md` for a session started
there to commit and delete.

## Splitting

- One concern per commit: docs → shared types/fields → implementation → tests.
- Two of *your* concerns in one file resisting a split → the commit of its
  PRIMARY concern.
- Explicit file lists only; NEVER push unless he explicitly says push.

## The procedure (shared checkout)

**0 · Parent and ownership.**

```sh
TIP=$(git rev-parse <branch>)
```

Ownership is the session's edit log — every edit as `(path, old, new)` — read
against the `git status --short` taken at session start and the file's own hunks
(`git diff -U1 HEAD -- <file>`). A hunk is yours because you applied it;
plausibility settles nothing. **PURE** = parent blob + exactly your edits.
**MIXED** = carries edits not yours too. **FOREIGN** = nothing of yours. Write a
shared file only from a read made this session, after checking it still hashes
the same — a stale whole-file Write deletes committed work.

**1 · Build the tree in a private index.**

```sh
export GIT_INDEX_FILE=/tmp/z_<name>.idx
git read-tree "$TIP"                  # seed: the parent's exact tree
```

- PURE: `git add <path>` — writes the private index, nothing else.
- MIXED: rebuild from `git show "$TIP":<path>` + your `(old, new)` pairs, each
  asserted; `git add` the rebuild. The worktree keeps the owner's part. If your
  pairs cannot be asserted against the parent blob, the file is not yours to
  commit — leave it and name it in the report.
- FOREIGN: not in your edit log ⇒ not in the index.

```sh
tree=$(git write-tree); unset GIT_INDEX_FILE
```

**2 · Commit with explicit identity.**

```sh
commit=$(git commit-tree "$tree" -p "$TIP" -m "type(scope): subject")
```

Record the hash the moment it exists — undo resolves by that hash.

**3 · Assert the tuple.**

```sh
git diff --stat "$TIP" "$commit"              # exactly your files
git diff "$TIP" "$commit" -- <mixed file>     # equals your pairs
```

**4 · Publish compare-and-swap.**

```sh
git update-ref refs/heads/<branch> "$commit" "$TIP"
```

A peer moving the branch makes this fail — re-capture `TIP`, rebuild from
step 1. The ref is never forced.

**5 · Re-sync the shared index per landed path.**

```sh
bash -c '
for p in <every landed path>; do
  git ls-tree HEAD -- "$p" | while read -r mode type sha name; do
    git update-index --add --cacheinfo "$mode,$sha,$p"
  done
done'
```

The shared index belongs to whoever stages in it — per path with `--cacheinfo`,
never a whole-index `read-tree HEAD`. (Under `bash -c` because zsh does not
word-split an unquoted `$VAR`.)

**6 · Undo (unpushed), by captured hash.** `HEAD~1` resolves at run time; a
peer may have landed in between.

```sh
git update-ref refs/heads/<branch> <parent> <hash>     # your commit is the tip

# a peer commit sits on top: re-parent theirs, then CAS to it
an=$(git show -s --format=%an <theirs>); ae=$(git show -s --format=%ae <theirs>)
export GIT_AUTHOR_NAME="$an" GIT_AUTHOR_EMAIL="$ae" \
       GIT_AUTHOR_DATE="$(git show -s --format=%aI <theirs>)"
export GIT_COMMITTER_NAME="$an" GIT_COMMITTER_EMAIL="$ae"
new=$(git show -s --format=%B <theirs> | git commit-tree <theirs>^{tree} -p <good-parent>)
git update-ref refs/heads/<branch> "$new" <current-tip>
```

No `reset --hard`; the working tree is never touched.

## Exclusions and output

- `~/metascript/recompiler`: `docs/*` and `CLAUDE.md` are tracked — commit this
  session's hunks as `docs(...)` commits.
- Never commit build outputs (`out/`, `*.o`, `.cache`), editor droppings or
  probes unless he asks by name.

After committing, show `git log --oneline -N`, then one line on what was left
uncommitted (junk, exclusions, a MIXED file left to its owner and why), one
line naming the peer work left untouched and the check proving it survived,
and — in an own worktree — the land command that comes next.
