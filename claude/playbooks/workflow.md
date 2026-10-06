# Workflow — how an instruction is written, and how a failure improves it

Read this before changing an instruction (`CLAUDE.md` at any level, a playbook, a skill) and
before touching memory. It is a rule, not a log.

## An instruction says what to do, and why

A session acts on what its instructions tell it to do. An instruction that only names what is
forbidden leaves the session holding the ban and guessing at the action, so it applies the ban
where it does not fit and misses the case the ban was written for.

Write each instruction as the decision it asks for:

- **The action and its condition.** "When X, do Y; otherwise do Z." A limit is the condition
  under which the other action applies, written with that action.
- **The reason, in a clause.** The reason lets a session handle the case the text did not
  list. "Queue the land, because the queue gates it once against the base it lands on."
- **The judgment the session makes, not the tool it calls.** A tool is how a decision is
  carried out. When the text says "run X" without the decision X serves, a session runs X
  where the decision would have said otherwise.

## A failure is fixed where the instruction that produced it lives

When a session decides wrong, or the person corrects how it worked:

1. Name the decision that went wrong, in one sentence: what the session concluded, and what
   it should have concluded.
2. Read the instruction layers that session had, in order: global `~/.claude/CLAUDE.md`, the
   workspace `CLAUDE.md`, the repository `CLAUDE.md` and its imports, the playbooks they name,
   and any skill that ran.
3. Find the passage that drove the decision. It usually has one of three shapes: the case is
   missing, a mechanism is described as if it were the procedure, or a ban stands without
   the action it protects.
4. Rewrite that passage in the layer that owns the topic so it says how to decide correctly,
   with its reason. Owners: global for every project, workspace for the repositories it maps,
   the repository for its own tools and gates, a playbook for a practice several places
   share.
5. Read the rewrite against the failing case and against the case the old text was written
   for. A session reading it acts right on both.

Report the change as: the decision that went wrong, the passage that caused it, the new text.

## Memory holds preferences and pointers

Memory carries what the person prefers (language, tone) and pointers to where state lives
(an arc's card, a machine's paths). A lesson about how to work belongs in the instruction
that governs that work, a technical fact in a test, a tool or a doc, so the next session
reads it where it acts. When a correction arrives, follow the steps above; when memory
already holds a lesson, move it into its instruction layer and delete the memory file.

## Worked example — the land gate

A session bumped `VERSION` in `src/compiler/usage.ms` and queued the land for a full gate.
The string is read only by `msc --version`, and no test or corpus program pins it, so no
lane could observe the change.

- Decision that went wrong: "every land is gated" instead of "this change reaches no lane".
- Passages: the repository and workspace texts described the land queue (it rebases, gates,
  lands) as the procedure, and left "what a lane looks at" to `gate.sh`'s path map; the only
  text on the other case was "an agent does not reach for `--no-gate` on its own".
- New text: decide what verification a change needs from what it can alter and which lane
  observes that; queue the land when a lane can, and when none can, show the evidence and
  land with `--no-gate` on the person's yes.
