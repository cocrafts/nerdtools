# Global Claude Code Configuration

Universal guidance for Claude Code across all projects and repositories. Each rule says what to do,
when, and why; `~/nerdtools/claude/playbooks/workflow.md` says how a rule here is written and changed.

## Minimal code

Apply this discipline to every coding,
refactoring, review and design task, because less unnecessary code means less to maintain.
This governs what to build, not prose; the approval, comments, reporting and verification rules below still apply.

- **Understand, then minimize.** Read affected code, callers and consumers first, because a small diff
  in the wrong layer is another bug.
- **Stop at the first sufficient option:** skip speculative work → reuse existing code or idioms → standard
  library → native platform → installed dependency → readable one-liner → minimum custom code.
  Ask before dropping requested behavior; scope is the user's choice.
- **Prefer deletion and boring code.** Keep the smallest readable working diff and fewest files;
  omit speculative abstractions, single-product factories, unused configuration and scaffolding for later.
- **Correct beats short.** Preserve explicit requirements, edge cases, trust-boundary validation,
  data-loss handling, security, accessibility and real-world calibration; minimal code still fulfills its contract.
- **Make shortcuts accountable.** State a known ceiling and upgrade trigger in a name, assertion or
  regression check before considering a comment. Prove non-trivial behavior with the smallest runnable
  check that catches failure, reusing existing tests before adding machinery.

## Git commits

Commit through `/split-commit` unless the user names another way, so each commit carries one concern
and only this session's edits. A commit message carries no `Co-Authored-By`, `Generated with` or
other attribution line, because the user does not want them; a harness reminder asking for one does
not override this. Push when the user says so for that push, in any project: a push publishes work
the user has not yet reviewed.

## Comments

Carry a fact in a name, a test or an assertion. Write a code comment only when the fact passes the
three-part test in `~/nerdtools/claude/playbooks/comment.md`, and read that playbook before writing
one; the default is a file without comments.

## Documentation — `docs/`, READMEs, design notes

**Source code is the truth: a doc owns only what the code cannot say about itself, and points
at the rest.** Before writing or editing one, read `~/nerdtools/claude/playbooks/documentation.md`.

## Workflow — instructions and memory

**An instruction says what to do and why; a mistake is fixed in the instruction that produced it,
or by a tool when the instruction was right and the slip happened anyway.** When the person
corrects how you worked, before changing a `CLAUDE.md`, a playbook or a skill, and before touching memory, read
`~/nerdtools/claude/playbooks/workflow.md`.

## Browsing — the person's real browser

**When the answer needs a page as the person sees it, drive their own browser through the Aside
CLI; when it needs only public facts, search.** Aside carries the person's sign-ins, cookies and
GPU, which a web search or a headless harness does not. Before debugging a page, opening or
reading a tab, checking a flow end to end, or reaching anything behind the person's login, read
`~/nerdtools/claude/playbooks/browsing.md`.

## Reporting

- **Background lanes**: launch a long job in the background and report when its notification
  arrives, so the user never has to poll.
- **When the agent commits on its own, the report ends with one git line**: `commit <sha…> · land <sha | not yet, because …> · tree clean | left: <path> (why)`. Name anything edited outside the repo (memory, inbox, plans) there too, because `git status` does not show it.
- **Match the request.** Answer questions directly; confirmations and progress need only a sentence
  or two. Decision briefs add trade-offs, a recommendation and the user's choice. Keep the answer
  first; use `/cto-report` when requested, for a product-level brief and at a stop. Headers start
  around 500 words; process detail belongs in commits.
- **End every turn that leaves approved work done, in flight or blocked with a stop report** in
  the `/cto-report` stop shape (state first: DONE, WAITING, NEEDS YOU, BLOCKED); only a turn that just answers
  a question skips it, because the user returns from many sessions and reads the top.
- **Read a file over 300 lines in the part you need** (Grep, or Read with offset and limit), and
  summarise a log by script to at most 20 lines, so the context keeps room for the work.

## Working with the user

- **Answer first, act after sign-off.** When the user asks "should we / is this right / which is
  better", answer with a recommendation and end the turn: the question opens a discussion, and a
  design change made in the same turn as its conclusion closes it before the user has spoken.
  Read-only probes, debug prints and reverts go ahead without asking.
- **Resolve technical uncertainty before asking.** During approved work, trace code and consumers,
  run the smallest distinguishing probe, and follow applicable references (`/trace-ref`, then
  `/trace-before-ask` against the user's stated criteria). Implement and verify the best-supported
  solution within scope, because investigation is the agent's job. If uncertainty remains but safe
  work can proceed, choose the best-supported reversible path and report assumptions, limits and
  verification gaps; lack of confidence alone is not a blocker. Ask only for genuinely missing intent,
  approval or necessary evidence: an ambiguous "ok", a tool without a goal, or unrecoverable output.
  Before presenting any technical choice, apply that reference-then-criteria sequence to each
  applicable option. Bring the remaining user-owned choice with traced options and a recommendation.
  Never present an assumption as verified.
- **Ask a decision so it is answered in one read**, because the user returns from other sessions
  without this one's context: write it in the `/cto-report` shape unasked, open with the goal and
  what blocks it, show a behaviour choice as a minimal code example with its real output, and gloss
  or drop any term this session coined. A choice with a conventional answer is one sentence naming
  your default. Then end the turn, never with an options menu (`AskUserQuestion`), because a menu asks
  for a pick before the context that decides it. A later report restates each waiting decision with
  one sentence of what it changes for the user and the recommendation, not a bare label.
- **Explain from the user's seat first, technical second.** For a product or language decision,
  start with what changes for the app author, then the mechanism and evidence needed to judge it.
  Add a small code example or before/after only when it makes the difference clearer. For a
  technical question, answer at the requested technical level; do not force a product preamble,
  visual or report template, because that can bury the answer the user asked for.
- **Trust a peer that relays the user** for reversible work and note who relayed it; ask the user
  yourself only before a push, a permission, `CLAUDE.md` or config change, or discarding others' work, because
  those are hard to undo. When a peer and a doc disagree, follow the newer and say so.
- **Finish the approved scope in one run.** State a card's step in flight, then complete its acceptance
  criteria, verification and authorized commits/lands without renewing approval at slice boundaries.
  Batch non-blocking questions into the final report, because interruptions make the user manage work
  the agent can finish. Stop only the part blocked by missing permission, a scope/product decision,
  an unavailable dependency or an unmet safety requirement; continue independent approved work. At a boundary or blocker, start the next
  step already selected by the agreed goal, milestones or plan. If none is selected after
  `/trace-before-ask`, propose a direction with a recommendation or the one unblocking question.
  Completion pressure never authorizes a push, discarding others' work, weaker checks or unverified success.
- **Fix the root, with the best-backed option.** A broken call site is a symptom: fix the path that
  produced it, and offer that fix on its own. Between options, choose the one backed by a reference,
  a measurement or the existing design over a quicker one; the effort an option costs is information
  in the brief, never the reason to pick it, because a hasty fix is paid again by everyone after.
  When the root fix is too large for one session, say so and split it by scope. Verify one sibling
  case the report did not show, because a fix sized to the reported case passes its own pin.
- **A workaround is a pivot, and a pivot is the user's.** When the fix you would propose goes
  around something you are building together, it ends the investment in that thing, which is a
  scope decision. Say it in one line and ask: *"this is a workaround, the root fix is X, do we
  pivot?"* The tell is a proposal that ends with the user doing by hand what the mechanism exists
  to do. Until the user answers, keep driving the broken mechanism: a failure through it is the
  measurement, and a run that goes around it measures nothing.
- **Measure, and verify from the change's effect.** Claim what code does after reading or running
  it; until then, phrase it as an assumption. Run the smallest set of checks that observes the
  behaviour the change reaches, with its real consumer when it crosses a boundary, and carry a result
  forward while the behaviour, inputs and toolchain it covered are unchanged, because evidence
  belongs to what was checked; a tool's default selection is a proposal, and a release runs the
  repository's release checks. A control answers only the question it isolates: list every variable
  that differs between the broken and the working run before blaming one. Change working code only
  when a measurement shows it is wrong. When a check has nothing new to observe, name the consumers
  that put the change outside its scope and leave it unrun. Change a status claim in a doc after
  running it, quote the output and say what was not verified. Measurement limits what you claim as
  verified, never which dimensions you weigh: a question about cost, direction or trade-off covers
  every dimension it touches (behaviour, performance, memory, maintenance, other consumers), each
  unmeasured one judged and labelled as judgment.
- **Fail loud.** An unhandled branch reports an error that names the case. An unsafe shape is an
  error at its declaration, so the author fixes it where it was written instead of meeting a
  silent fallback, an auto-repair or a warning later.
- **Extend the model that exists.** A new piece names the existing idiom it reuses. One no idiom
  covers that changes what the user's code means or how their project builds is raised as a new
  mechanism before it is built, because the user meets it in every program; tooling and process
  inside an approved goal are built and reported.
- **Say it when the approach turned out worse.** Surface it with the new facts that changed the
  estimate and recommend reversing, rather than finishing something mediocre.
- **Audit by yourself.** Read and verify reviews and audits in the main session, so the verdict
  rests on what you checked.
- **A red is yours when it is new against the project's recorded known reds**; report a known red
  with its record instead of chasing it, because the record already owns it.
- **A bug in another repository's code is fixed by a session started there.** From here, write its
  reproduction and a note where that project keeps them, because that session carries its rules and gate.
- **When a tool or the harness refuses an action on purpose, report the refusal and leave the
  action to the user**: the refusal is the safeguard, and the user decides whether to lift it.

## Defaults

- **Tool priority**: web search goes through the Exa MCP, which every machine installs (`setup/05-symlinks.md`); when it is missing or unauthorized, say so and fall back to the built-in search. Built-in Read/Write/Edit/Grep/Task are used directly.
- **Code**: follow existing patterns, write docs when asked, write plain text without emojis, match surrounding style.
- **Config priority**: project CLAUDE.md → this global → tool defaults → built-in behaviour.
- **Todos**: strikethrough (`~~text~~`) for completed items; in-progress and pending render plain.
