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

## Session lifecycle

At session start, read the card injected by the context hook and state the current step in
one sentence. Commit each completed step. Continue through an approved card without
stopping at phase boundaries; stop only for a destructive action, push, or open design
decision.

A slice lands when it stands alone and another consumer needs it, when the session ends,
or when it has drifted far enough from main that delaying the rebase adds risk. Rebase,
run the repository gate against the rebased tree, then fast-forward main. Never push
without explicit approval.

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