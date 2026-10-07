# Worktrees — one arc, one branch, one durable card

Read this playbook only when a workspace or repository explicitly opts into it. A project
opts in by naming this path in its own `CLAUDE.md` and requiring the session to read it;
project-level `@` imports cannot reach files outside that project.

## Unit of work

A feature or named arc owns one branch `wt/<name>`, one linked worktree, and one card.
Reuse that worktree across sessions. Sequential steps are commits in it, not new
worktrees. Create a second worktree only for genuinely concurrent, path-independent work
or for an unrelated fix that must land separately.

The main checkout receives lands only. Do not develop there in a workspace that opts into
this flow.

## Card

The default card is `<main checkout>/.cards/<name>.md`. A workspace may instead own a
shared `<workspace>/.wt/<name>.md`; that override belongs in the workspace rules. The card
contains Goal, Done when, and a short State that lets a new session start without another
transcript. Memory points to the card and never copies it.

Update State before a session ends. Delete the card only after Done when holds on the main
branch and every fact worth keeping has moved into code, tests, or tracked documentation.

A session that hands its worktree to a fresh one also writes `<card root>/handoff/<name>.md`.
That file holds what is true now but not durable: local artifacts, machine conditions, traps met,
and the person's recent words. It lives for one session. The context hook prints it before the
card, and the receiving session deletes it once its first step is under way. The
`worktree-relaunch` skill is the procedure.

## Kickstart — the line the person pastes

A session that leaves work for another session ends its reply with one line per session to
open, in the order to run them, each marked with when: now, after `<name>` lands, or when a
worker slot is free. The person pastes the line and nothing else.

- **A worktree exists:** `cd <worktree>; claude`. The context hook injects the handoff (if any)
  and the card, so the line carries no prompt.
- **No worktree yet:** this covers a brief for another repository, whose worktree only a
  session started there may create, and an inbox note. The line is
  `cd <main checkout>; claude "Read <absolute path of the brief> and run it."`, and the brief
  says which worktree to create.

A card or brief ends with the same line under `Kickstart:`, so a later reader finds it without
the transcript. The line runs unchanged in PowerShell, bash and zsh.

## Session lifecycle

At session start, read the card injected by the context hook and state the current step in
one sentence. Commit each completed step. Continue through an approved card without
stopping at phase boundaries; stop only for a destructive action, push, or open design
decision.

A slice lands when it stands alone and another consumer needs it, when the session ends,
or when it has drifted far enough from main that delaying the rebase adds risk.

Before landing, check what can refuse the transaction and rebase onto the intended main.
Compare the resulting changes with the scope of the recorded verification: which behavior,
inputs, toolchain and settings its checks observed. Choose verification by the global
CLAUDE.md rule, then satisfy that decision and fast-forward main. Push on the user's explicit
approval, because it publishes the work beyond the local checkout.

Carry a GREEN result forward when that checked scope is unchanged, including after a commit,
rebase or refused land. When something in its scope changes, rerun the affected checks.
Record the checked commit and base as provenance along with the scope and result, so another
session can establish whether the evidence still applies rather than inferring it from a SHA.

Land with `--no-gate`, without asking, when all of these hold: the branch's card quotes a
GREEN gate result with its commit and toolchain, main's last land was gated GREEN on the same
toolchain, `land` prints `files changed on both sides: none`, and it prints
`previous land: gated`. Record the reason in the card. When any of them fails, run the gate,
because two GREEN sides that share a file, or a chain of ungated lands, leave the combination
unobserved; a gated land after every ungated one keeps that window to a single land.

Retire a worktree from outside it. Refuse removal while it contains uncommitted files,
unlanded commits, or live processes unless the person explicitly chooses to discard the
named state.

## Shared tool

`~/nerdtools/claude/tools/wt.sh` owns the generic Git lifecycle, card lookup, safety checks,
and session context. Run it from the repository or pass the intended directory through
`WT_CWD`. `help` is the command reference.

The tool discovers the repository main checkout, defines its default commands and no-op
extension hooks, then sources `<main checkout>/tools/wt.sh` before dispatch when that file
exists. The main checkout is deliberate: an unlanded branch must not rewrite the mechanism
that gates or lands itself.

A repository-local adapter contains declarations only—no top-level dispatch and no call
back into the shared tool. It may redefine a `cmd_*` function for a full command override,
or define the narrow `wt_before_*`, `wt_after_*`, and `wt_context_extra` hooks to compose
with the generic command. Repository-specific provisioning, gates, inboxes, generated
artifacts, and release policy belong there; none belong in the shared tool.

Claude Code and omp both invoke the shared `context` command. Do not add a second card
reader to a project hook.