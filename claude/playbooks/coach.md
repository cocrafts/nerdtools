# Coaching worker sessions from a centre session

One Claude session supervising several long-running autonomous ones. **This is a log, not a
manual**: it is day one — 2026-09-20, two workers (`wt/void2d-gpui`, `wt/void3d-m5`), one
coach, one human, six orders sent. Every practice below has been exercised about once, so read
them as "tried, did not break yet", not as established. Numbers are marked measured or
estimated; the estimated ones are in §4 for a reason.

## The shape

- One **worker** per worktree, in `bypassPermissions`, driven by a prompt card in
  `~/metascript/.wt/<name>.md` that owns its scope, gate and review loop.
- One **coach**: an ordinary session that reads worker state and sends orders via
  `ListAgents` / `SendMessage`. It writes no code in their repos.
- The human talks to the coach, and approves every order before it is sent.

## Channels, cheapest first

| channel | cost to the worker | use it for |
|---|---|---|
| **Artifacts** — arc card, `git log`, gate output | nothing; it never knows | every routine check |
| **Transcript**, filtered in a script | nothing | what it is doing *right now*, or when the card is behind |
| **Ask it** | a turn, its context, an interrupt | orders, and only questions not answerable from disk |

Measured: the two transcripts were 6.6 MB and 3.8 MB — the larger is past what a 1M context
holds — against arc cards of 7.6 KB and 5.9 KB. So a transcript is filtered in a script, never
read whole. Worker context is the scarce resource: both hit 686k / 443k tokens and needed
`/compact` on day one.

The card works as a status channel because the worker's brief already orders it updated after
every phase. Reading it is reading a report it had to write anyway.

## Practices

1. **Draft the order, human approves, send verbatim.** Reading needs no approval; commanding
   does.
2. **Batch.** *Not yet honoured*: day one was six separate messages, which is the thing this
   rule exists to prevent. Until a day passes at one or two, treat it as an intention.
3. **Challenge a claim whose evidence is one category short of its conclusion.** A worker
   claimed the campfire could not move onto a model matrix and stay byte-identical, on evidence
   that box corners differed by ~4 ulps — floats supporting a claim about images. Told to run
   the capture, it came back identical on all six configurations and the milestone stayed
   whole.
4. **Demand a control for every null result.** "Nothing changed" from a binary that did not
   recompile is the expensive kind of wrong.
5. **Verify before accusing.** Both branches had landed on `main` against cards saying that was
   the human's job; the transcripts showed the human had authorised it an hour earlier.
6. **Retract in one message and do not defend the error.**
7. **Match permission modes**, or every order waits on a human click.

## The coach's own failure mode, which is worse than the worker's

The coach ordered a worker to decide something `docs/VOID3D.md` had already decided. The worker
did not push back — it researched, decided, landed on the same answer the doc held, and
committed it as fresh. The human caught it, not the worker.

**A worker argues with a reviewer and complies with a coach**, so a coach's error propagates
faster and more quietly than its own. Mitigations: read the decision docs in full before
ordering anything architectural, and mark which instructions are the coach's so they can be
vetoed.

## Open questions — measure, do not argue

Day-1 figures here are **self-graded by the coach**, which is the same circularity the coach
criticises elsewhere. Treat them as a starting point to instrument, not as findings.

| question | metric | what the answer changes |
|---|---|---|
| Does coaching pay for itself? | interventions that changed an outcome ÷ sent. Day 1: 1 of 6, self-graded | below ~1 in 5, the coach should only dispatch and report |
| What does a check cost? | tokens per check, per channel, **instrumented** — every figure today is an estimate | cheap ⇒ check more often; not ⇒ subscribe instead |
| Is the coach a net source of defects? | coach errors ÷ orders, and how many the *worker* caught. Day 1: 1 introduced, 0 caught by the worker | if workers never catch them, every order needs "push back if this contradicts a doc" |
| What does it cost the **human**? | minutes spent approving and reading, per worker per day | this is the scarcest budget and nothing measures it |
| How long until a wrong turn is noticed? | time from divergence to detection | long ⇒ the gate is the wrong granularity |
| What is worker utilisation? | working ÷ wall-clock. Day 1: 1h36m and 57m of 8h; both idled ~6h40m | under ~50% the bottleneck is the harness, not the agent |
| What do the review passes miss? | classes, not counts. Day 1: 13 findings across two passes, none noticing void3d has **no ms/frame measurement at all** | a recurring miss belongs in the review brief, not in coach habits |

## Untested

More than two workers · a coach across machines · a coach surviving its own restart · a coach
allowed to block a milestone rather than leaving the verdict to the worker's review loop.
