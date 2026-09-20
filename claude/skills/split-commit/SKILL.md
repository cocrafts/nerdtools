---
name: split-commit
description: Commit pending work as a series of SMALL logical commits with short conventional messages, no body, no attribution. Commits are CONSTRUCTED from the session's enumerated edits in a private index seeded from a captured parent — peers cannot ride along by construction, so there are no prohibitions to remember. Use when the user says /split-commit or asks to commit "theo rule cũ / chia nhỏ commit". Encodes per-repo exclusions.
---

# split-commit — chia nhỏ commit theo rule của Sơn

Commit the current work as a series of small, logical commits. This skill runs
when the user asked to commit, or when the project's CLAUDE.md lets the agent
commit on its own (the `~/metascript` workspace does); elsewhere never volunteer
commits.

**Two jobs, in this order: (1) commit ONLY what this session wrote, (2) split it
into small logical commits.** Job 1 outranks job 2. A perfectly split commit that
carries a peer's half-finished WIP, or that silently reverts their work, is worse
than one slightly-too-large commit containing exactly your own changes.

**How this skill achieves that:** a commit is a tuple you construct — parent,
tree, message — never a filter over current state. The session's edit log is the
only source of content; the parent is captured by hash. Everything a peer does
(index staging, worktree edits, ref moves) happens outside that tuple and stays
outside it by construction.

**Where bans remain:** only where a prohibition overrides a default of the tool or
the model — attribution footers, commit bodies, volunteering pushes — because those
fire unless negated, and where it blocks a destructive action (force, push). A ban
that patches an accident of this skill's own procedure is a design bug: fold the
accident into the construction and delete the ban.

## Message format (HARD RULES)

- `type(scope): subject` — conventional commits. Types: feat, fix, refactor, docs, test, chore, perf, ci, build.
- **Subject ngắn gọn. KHÔNG body, KHÔNG description, KHÔNG bullet list.** One `-m` only.
- **KHÔNG attribution footer** (no Co-Authored-By / Generated-with — attribution is disabled globally in his settings).
- Match the repo's existing scope convention (`git log --oneline -15` first; e.g. urg uses `feat(engine):`, `docs(engine):`).

In `~/metascript` these four rules are **enforced**, not remembered: `.githooks/commit-msg`
(reached through `core.hooksPath`, so every linked worktree inherits it) rejects a subject
that is not `type(scope): subject`, any body or bullet list, and attribution in the subject.
`Merge`, `Revert`, `fixup!` and `squash!` are exempt.

---

## First: own worktree or shared checkout

```sh
git rev-parse --show-toplevel        # where this session works
git worktree list | head -1          # the main checkout
```

- **Own linked worktree** (the two differ — e.g. recompiler's `wt/<name>` branch from
  `tools/wt.sh new`): the working tree and the index are private, so ownership is
  settled by construction. Read `git status --short` once for junk, commit with
  ordinary `git add <explicit files>` + `git commit`, and stop — the procedure below
  is already your situation, minus the capture/CAS ceremony.
- **Getting that branch onto `main` is the repo's land step, not this skill** —
  `tools/wt.sh land` in recompiler (rebase, gate, compare-and-swap `main`, sync the
  main checkout path by path); in the other `~/metascript` repos (neon, ion, void,
  yoga, lightcube) plain git as `~/metascript/CLAUDE.md` §Arcs spells it:
  `git rebase main`, the repo's gate, `merge --ff-only`. Never copy files into the
  main checkout to commit them there, never commit an arc's work on `main` directly,
  no push or pull between checkouts.
- **Shared checkout** (the two match, or peers edit this same tree): run the
  procedure below. In a `~/metascript` repo that is the main checkout, which takes
  lands plus the small change that belongs to no arc (setup, a doc line, an inbox
  note's edits).
- **A sibling repo's file edited from this session** is committed in that sibling's
  shared checkout, by the rules below, before this session isolates itself in a
  worktree — afterwards git outside the worktree is refused: the edit stays uncommitted
  and is named in a note `~/metascript/.inbox/<repo>/<yyyy-mm-dd>-<slug>.md`, which a
  session started in that repo reads, commits from and deletes.

---

## Ownership is the session's edit log

```sh
git status --short                   # at session START, before the first edit
git log --oneline -5                 # and again now — the tip may have moved
```

The session's edit log — every edit it applied, as `(path, old, new)` — is the
complete and only definition of what it owns. Classify each changed file against it:

- **PURE** — the worktree file equals the parent blob plus exactly your edits.
- **MIXED** — it also carries changes you did not apply; your part is still exactly
  your enumerated `(old, new)` pairs.
- **FOREIGN** — nothing in it came from your edit log. It stays untouched.

Read a file's own hunks to classify it:

```sh
git diff -U1 HEAD -- <file> | grep -E '^[+-]' | grep -v '^[+-][+-]'
```

A change is yours because it is in your edit log — you applied it this session.
Plausibility settles nothing: a peer on a neighbouring feature writes code that
looks exactly like yours. When you cannot trace a hunk to your own log, the file
is FOREIGN for your purposes.

Write-tool rule, same principle: write a shared file only from a read made in this
session, after checking the file still hashes to what that read saw; otherwise
re-read first. (A whole-file Write from a stale read silently deletes committed
work — the check makes that impossible instead of memorable.)

---

## How to split

1. Group your edits into logical units — one concern per commit. Typical sequence:
   - docs first (if standalone),
   - shared types/fields BEFORE the code that uses them (each commit should compile on its own),
   - implementation next,
   - tests that pin the implementation last (or right after their subject).
2. A file carrying two of *your* concerns that resist a clean split → put it in the
   commit where its PRIMARY concern lives.
3. `git add` with **explicit file lists only** — the commit's content comes from
   your enumeration, so `<dir>` and `-A` have nothing to offer and sweep junk
   (probes, `*.o`, `out/`) and peer files besides.
4. NEVER push unless he explicitly says push.

---

## The procedure (shared checkout)

One commit at a time, in full:

### 1. Capture the parent by hash

```sh
TIP=$(git rev-parse <branch>)        # e.g. refs/heads/main
```

Everything you build hangs off `$TIP`. Resolve the branch again only through the
CAS in step 5.

### 2. Build the commit's tree in a private index

```sh
export GIT_INDEX_FILE=/tmp/z_<name>.idx
git read-tree "$TIP"                 # seed: the parent's exact tree
```

For each file in this commit's unit, from your edit log:

- **PURE** file: `git add <path>` — with `GIT_INDEX_FILE` exported this writes the
  private index and nothing else.
- **MIXED** file: rebuild it — start from `git show "$TIP":<path>`, apply your
  enumerated `(old, new)` pairs with a script that asserts each `old` matches,
  then `git add` the rebuilt file. The worktree keeps the rest (the owner's
  changes); your commit carries exactly your pairs. When your pairs cannot be
  asserted against the parent blob — the file's tracked state has diverged so far
  that "your part" is not reconstructible — the file is committed whole by its
  owner when they choose; you leave it and name it in the report.
- **FOREIGN** file: absent from your edit log ⇒ absent from your index.

```sh
tree=$(git write-tree)
unset GIT_INDEX_FILE
```

### 3. Commit with explicit identity

```sh
commit=$(git commit-tree "$tree" -p "$TIP" -m "type(scope): subject")
```

`git commit-tree` takes exactly the tree and parent you built — there is no
worktree re-read and no shared index in the path. Record `$commit` the moment it
exists; undo is done by that hash, never by a relative ref.

### 4. Assert the tuple before publishing

```sh
git diff --stat "$TIP" "$commit"              # exactly your files, nothing else
git diff "$TIP" "$commit" -- <mixed file>     # equals your enumerated pairs
git diff "$commit" -- <mixed file>            # the owner's changes, still in the worktree
```

### 5. Publish compare-and-swap

```sh
git update-ref refs/heads/<branch> "$commit" "$TIP"
```

A peer moving the branch since step 1 makes this FAIL — that is the desired
outcome. On failure: re-capture `TIP`, rebuild from step 2 against the new
parent, publish again. The ref is never forced.

### 6. Re-sync the shared index, per path

The shared index belongs to whoever is staging in it — typically a peer. Bring
your landed paths up to the new HEAD, one path at a time:

```sh
bash -c '
for p in <every path you just landed>; do
  git ls-tree HEAD -- "$p" | while read -r mode type sha name; do
    git update-index --add --cacheinfo "$mode,$sha,$p"
  done
done'
```

Per path, with `--cacheinfo`; a whole-index `read-tree HEAD` resets everything and
discards the peer's staging. The loop reads ls-tree's fields with `read`, never a
quoted-awk pipeline, and runs under `bash -c` because zsh does not word-split an
unquoted `$VAR`.

---

## Undo (unpushed commits)

Undo resolves commits by the hash captured when they were made. `HEAD~1` and
friends resolve at run time — by then a peer may have landed on top, and the
"undo mine" would remove theirs.

**Your commit is the tip** (nothing on top):

```sh
git update-ref refs/heads/<branch> <its parent> <its hash>    # CAS
```

**A peer commit sits on top of the one you undo:** re-parent their commit onto
the good parent, preserving authorship, then CAS the branch to it:

```sh
an=$(git show -s --format=%an <theirs>); ae=$(git show -s --format=%ae <theirs>)
ad=$(git show -s --format=%aI <theirs>)
export GIT_AUTHOR_NAME="$an" GIT_AUTHOR_EMAIL="$ae" GIT_AUTHOR_DATE="$ad"
export GIT_COMMITTER_NAME="$an" GIT_COMMITTER_EMAIL="$ae"
new=$(git show -s --format=%B <theirs> | git commit-tree <theirs>^{tree} -p <good-parent>)
git update-ref refs/heads/<branch> "$new" <current-tip>   # CAS
```

Then re-sync the index for the paths that differ between the old and new chain
(step 6 of the procedure).

Recovery never needs `reset --hard`; the working tree is never touched.

---

## Per-repo exclusions

- `~/metascript/recompiler`: `docs/*` and `CLAUDE.md` are tracked: commit the hunks
  this session authored, as `docs(...)` commits.
- Any repo: never commit generated build outputs (`out/`, `*.o`, `.cache`),
  editor droppings, or experiment probes unless he asks by name.

## Output

After committing, show `git log --oneline -N` for the new commits, then:

- one line on what was deliberately left uncommitted (junk / exclusions / a
  MIXED file left to its owner with the reason);
- in a shared checkout, one line naming the **peer work left untouched** (their
  staged files, their hunks in a MIXED file) and the check that proves it survived;
- in an own worktree, the land command that comes next; whether the agent runs it is
  the repo's rule (recompiler: a gated `tools/wt.sh land` is the agent's, `--no-gate`
  and push are asked for), not this skill's.
