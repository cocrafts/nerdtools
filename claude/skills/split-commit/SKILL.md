---
name: split-commit
description: Commit pending work as a series of SMALL logical commits with short conventional messages, no body, no attribution. Commits ONLY the hunks this session authored, safely, in a tree where other sessions work in parallel. Use when the user says /split-commit or asks to commit "theo rule cũ / chia nhỏ commit". Encodes per-repo exclusions (recompiler never commits docs/* or bun/*).
---

# split-commit — chia nhỏ commit theo rule của Sơn

Commit the current work as a series of small, logical commits. This skill runs
only when the user explicitly asked to commit (his default elsewhere is
stage-only — never volunteer commits).

**Two jobs, in this order: (1) commit ONLY what this session wrote, (2) split it
into small logical commits.** Job 1 outranks job 2. A perfectly split commit that
carries a peer's half-finished WIP, or that silently reverts their work, is worse
than one slightly-too-large commit containing exactly your own changes.

## Message format (HARD RULES)

- `type(scope): subject` — conventional commits. Types: feat, fix, refactor, docs, test, chore, perf, ci.
- **Subject ngắn gọn. KHÔNG body, KHÔNG description, KHÔNG bullet list.** One `-m` only.
- **KHÔNG attribution footer** (no Co-Authored-By / Generated-with — attribution is disabled globally in his settings).
- Match the repo's existing scope convention (`git log --oneline -15` first; e.g. urg uses `feat(engine):`, `docs(engine):`).

---

## 0. Ownership first — assume the tree is shared

Several Claude sessions commit into the SAME working tree (notably
`~/metascript/recompiler`). Before staging anything, establish what is yours.

```sh
git log --oneline -5                 # the tip may have moved since you started
git status --short                   # col 1 = index, col 2 = worktree
git diff --cached --name-only        # what a PEER left staged — never yours to commit
```

For every file you intend to commit, print its own hunks and read them:

```sh
git diff -U1 HEAD -- <file> | grep -E '^[+-]' | grep -v '^[+-][+-]'
```

Classify each file:

- **PURE** — every hunk is yours.
- **MIXED** — it also carries hunks you did not write.
- **FOREIGN** — none of it is yours (peer WIP, or peer-staged). Do not touch it.

You must be able to say, for each hunk, *why you believe it is yours* — you edited
that function this session, it is in your own edit log. If you cannot tell, treat it
as FOREIGN. **Never infer ownership from plausibility**: a peer working on a
neighbouring feature writes code that looks exactly like something you'd have written.

`git status --short` at session start is the cheapest ownership baseline available.
Read it before the first edit, not at commit time.

---

## How to split

1. Understand every changed file before grouping (step 0 already did the reading).
2. Group into logical units — one concern per commit. Typical sequence:
   - docs first (if standalone),
   - shared types/fields BEFORE the code that uses them (each commit should compile on its own),
   - implementation next,
   - tests that pin the implementation last (or right after their subject).
3. **A MIXED file is never committed whole.** Either reconstruct it (Method B) or
   hunk-filter it (Method C). "Don't over-engineer hunk surgery" applies only to
   splitting *your own* two concerns across two commits — never to letting a peer's
   hunk ride along.
4. A file carrying two of *your* concerns that resist a clean split → put it in the
   commit where its PRIMARY concern lives.
5. `git add` with **explicit file lists only** — NEVER `git add <dir>` or `git add -A`
   (it sweeps untracked junk: probes, `*.o`, `out/`, scratch files — and peer files).
6. NEVER push unless he explicitly says push.

**Banned in `~/metascript/recompiler`, and don't reach for them elsewhere:**
`git stash`, `git reset`, `git checkout .`, `git restore` — they discard working-tree
state belonging to another session. Every recipe below works without them.
`git reset -q -- <paths>` is NOT protection either: it clears only YOUR paths and
cannot stop a foreign index from riding along.

---

## Choose the landing method

| Situation | Method |
|---|---|
| All your files PURE **and** `git diff --cached` empty | **A — pathspec commit** |
| All your files PURE but a peer has files staged | **A** (pathspec ignores the index) |
| Any file MIXED, or you want maximum safety | **B — private worktree land** (default) |
| MIXED and a worktree is impractical | **C — hunk-filtered index** |

When in doubt use **B**: it is the only method whose index is not shared.

### Method A — pathspec commit (PURE files only)

```sh
git commit -m "type(scope): subject" -- <file1> <file2>
```

`git commit -- <paths>` takes those paths from the **WORKING TREE** and ignores the
index entirely, so a peer's staged files cannot ride along.

⚠ That same property makes A **forbidden after any hunk filtering** — the pathspec
re-reads the unfiltered working tree and re-imports the hunks you just filtered out.
A and C are mutually exclusive.

### Method B — private worktree land (default; the only private index)

```sh
TIP=$(git rev-parse <branch>)
git worktree add -f --detach /tmp/z_<name>_land "$TIP"

# copy in ONLY your files:
cp <your PURE files> /tmp/z_<name>_land/<same paths>

# for each MIXED file, rebuild it from the tip blob + only your edits —
# do NOT cp the working-tree version:
git show "$TIP":<path> > /tmp/z_<name>_land/<path>
#   then re-apply your edits there with a targeted script that asserts each match

cd /tmp/z_<name>_land
git add <explicit files>          # private index — verify with git diff --cached --name-only
git commit -m "type(scope): subject"
# …repeat per logical commit…

# publish atomically: fails instead of clobbering if a peer moved the branch
git update-ref refs/heads/<branch> <new-tip> "$TIP"
```

**Then re-sync the real index, per path** — skipping this is how your commit gets
silently reverted (Trap D):

```sh
bash -c '
for p in <every path you just landed>; do
  entry=$(git ls-tree HEAD -- "$p")
  git update-index --add --cacheinfo \
    "$(echo "$entry" | awk "{print \$1}"),$(echo "$entry" | awk "{print \$3}"),$p"
done'
```

Use `git update-index --cacheinfo` **per path**, never `git read-tree HEAD` — the
latter resets the whole index and discards the peer's staging.

Run that loop under `bash -c`: zsh does not word-split an unquoted `$VAR`, so it
executes once with every path glued into one token and prints a single "missing"
line that reads like a harmless warning while nothing is actually re-synced.

Finish with `git worktree remove /tmp/z_<name>_land`.

### Method C — hunk-filtered index (no worktree available)

1. `git diff -U1 HEAD -- <file> > /tmp/f.patch` — **`-U1`, not the default `-U3`**.
2. Filter the patch to your hunks only (a small python pass keyed on a **marker line**,
   never on hunk index).
3. `git apply --cached /tmp/f.patch`
4. `git add <your PURE files>`
5. **Commit with NO pathspec** — `git commit -m "…"`; the index commits as-is.
6. Because step 5 has no pathspec, the WHOLE index goes in: assert first that
   `git diff --cached --name-only` lists **exactly** your files and nothing else.

---

## After EVERY commit — the four-point check

```sh
git show --stat --oneline HEAD          # 1. file count == what you intended
git diff --cached --name-only           # 2. only the peer's files remain (or empty)
git status --short -- <your paths>      # 3. no staged M/D in column 1 for them
git show HEAD:<file> | diff -q - <file> # 4. landed blob == worktree (PURE files)
```

Plus, for any MIXED file you committed, grep for a **peer marker** — a symbol that
exists only in their WIP:

```sh
git show HEAD -- <mixed file> | grep -c '<peerSymbol>'   # must be 0 (didn't ride in)
git diff HEAD -- <mixed file> | grep -c '<peerSymbol>'   # must be >0 (still alive)
```

---

## Traps that have actually fired here

- **A. Bare `git commit` sweeps the whole index.** A 4-file change landed as 28 files
  / +1288−977 because a peer had 24 files staged, including deletions a later
  cherry-pick carried onto `main`. Gate on `git diff --cached --stat` with **no
  pathspec** before every bare commit.
- **B. The mirror: hunk-filtered index + pathspec commit.** The pathspec reads the
  working tree, so the peer's hunks rode in anyway — without the field their code
  depended on — and `main` stopped building. Filtered index ⇒ **no pathspec**.
- **C. `-U3` merges neighbouring hunks.** Two changes 6 lines apart emit as ONE hunk,
  so "pick hunk #2" takes a peer line too, while its required import sits in a hunk
  you didn't pick → HEAD calls an unimported symbol. Use `-U1`; never trust a hunk
  count taken at a different `-U`.
- **D. Plumbing commit without index re-sync ⇒ the peer's next commit REVERTS yours.**
  The real index still held the pre-commit blob; their commit carried
  `<your file> | 33 ---------` and HEAD lost your change while your worktree still had
  it, so nothing looked wrong locally. Always re-sync per path (Method B).
- **E. Whole-file `Write` from a stale snapshot** silently deletes committed work
  (`Edit` would have errored). Never rewrite a shared file from an old read.

Recovery for all of these is non-destructive and never needs `reset --hard`:
`git update-ref refs/heads/<branch> <old>` un-lands an unpushed branch move;
`git update-ref HEAD <parent>` un-commits while leaving the working tree alone — and
restores the peer's staged index exactly.

---

## Per-repo exclusions

- `~/metascript/recompiler`: **never commit `docs/*` or `bun/*`** — leave them
  modified/untracked no matter what changed there.
- Any repo: never commit generated build outputs (`out/`, `*.o`, `.cache`),
  editor droppings, or experiment probes unless he asks by name.

## Output

After committing, show `git log --oneline -N` for the new commits, then:

- one line on what was deliberately left uncommitted (junk / exclusions),
- one line naming the **peer work left untouched** (their staged files, their hunks
  in a MIXED file) and the check that proves it survived.
