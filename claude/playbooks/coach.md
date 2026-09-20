# Coaching worker sessions from a centre session

One Claude session supervising several long-running autonomous ones. **This is a log, not a
manual.** Day 1 was 2026-09-20 — two workers (`wt/void2d-gpui`, `wt/void3d-m5`), one coach, one
human. Day 2 is 2026-09-21. Practices carry the day they arrived; read them as "tried, did not
break yet", not as settled. Numbers are marked measured or estimated.

## What the coach is for — decided day 2, and it changes the voice of everything below

**The coach coordinates and communicates. It does not judge and it does not execute.**

Its value is the vantage no worker has: it sits outside every arc, it reads all of them, and it
has room to think about the whole while each worker is correctly buried in its own. So its job is

- to carry context between arcs,
- to get the right question to the right person in a form answerable in one beat,
- to keep the facts shared between arcs current,

and **not** to rule on whether a worker's work is good. The worker's own review loop does that,
and on day 1 it did it better than the coach three separate times.

This is not modesty, it is where the evidence points. Day 1: **6 coach errors across ~25 orders,
5 of them caught by a worker.** Every catch came from a worker going one level deeper into its own
arc than the coach had. A coach that spends its turns judging is competing with the thing that
already wins; a coach that spends them connecting is doing the only job nobody else can.

**So the practices below are phrased as asking, not as ruling.** When the coach challenged the
ulp-to-image inference on day 1 and the milestone stayed whole, what worked was not a verdict —
it was **a question the worker was not positioned to ask itself**. Keep that shape.

## The shape

- One **worker** per worktree, in `bypassPermissions`, driven by a prompt card in
  `~/metascript/.wt/<name>.md` that owns its scope, gate and review loop.
- One **coach**: an ordinary session that reads worker state and sends orders via
  `ListAgents` / `SendMessage`. It writes no code in their repos.
- The human talks to the coach, and answers the questions workers bring him.

## Channels, cheapest first

| channel | cost to the worker | use it for |
|---|---|---|
| **Artifacts** — arc card, `git log`, gate output | nothing; it never knows | every routine check |
| **Transcript**, filtered in a script | nothing | what it is doing *right now*, or when the card is behind |
| **Ask it** | a turn, its context, an interrupt | orders, and only questions not answerable from disk |

Measured day 1: the two transcripts were 6.6 MB and 3.8 MB — the larger is past what a 1M context
holds — against arc cards of 7.6 KB and 5.9 KB. So a transcript is filtered in a script, never
read whole. Worker context is the scarce resource: both hit 686k / 443k tokens and needed
`/compact` on day one.

The card works as a status channel because the worker's brief already orders it updated after
every phase. Reading it is reading a report it had to write anyway.

## The escalation loop — day 2, and it replaced the approval gate

Day 1's first practice was *"draft the order, the human approves, send it verbatim."* **That is
retired.** It put the human in the command path, where he is the bottleneck, instead of the
authority path, where he is irreplaceable.

What replaced it:

1. **The coach sends orders freely.** No per-order approval.
2. **A coach order is information, never authority** — and the workspace's own `CLAUDE.md` says
   so to every session, so the coach does not repeat it in each message.
3. **A worker that is not confident, or not willing, asks its own human in its own window** and
   acts only on that answer. This is the normal path, not a last resort.
4. **The coach never asks the human to run a command on a worker's behalf.** The worker asks,
   where the authority is.

Ran twice clean on day 2, on the two lands. void2d: *"I did not take your message as permission;
I asked the user in this window directly."* void3d, whose brief forbids merge and push and still
does, did the same. **This is the repair for coach error #5** — relaying a step a brief forbade —
not a way around it. A peer still cannot lift a prohibition a brief carries. What changed is who
carries the question.

**Measured: the human's cost collapsed.** Day 1 he approved ~25 orders; day 2 he answered **two**
escalations. That is the first real movement on the open question this playbook calls the
scarcest budget and admits nothing measures.

**Ask with the options enumerated, not openly** — a worker practice, so it belongs in the briefs,
and it is what keeps step 3 cheap. `AskUserQuestion` renders them, and **the options are where the
thinking goes**: void3d asked *land / land-then-re-gate / leave it*, so the answer said what it
covered. The coach first wrote this up as void2d having asked openly and got a bare word back —
**void2d corrected it**: it had also used enumerated options, and the word the coach quoted was a
label void2d itself had written. Both escalations that night were closed questions, 2 of 2. The
practice survived; the coach's attribution did not, and a worker caught it in a doc that was
already pushed.

## Practices

Numbered by arrival, not by rank.

1. ~~Draft the order, human approves, send verbatim.~~ **Retired day 2** — see the escalation loop.
2. ~~Batch.~~ **Demoted day 2.** Batching was medicine for the approval gate's cost. With the gate
   gone, most of the reason went with it: day 2 sent four orders, each on its own trigger, and
   batching them would have been *wrong* — each depended on the previous having landed.
3. **Ask the question the worker is not positioned to ask.** A worker claimed the campfire could
   not move onto a model matrix and stay byte-identical, on evidence that box corners differed by
   ~4 ulps — floats supporting a claim about images. Asked to run the capture, it came back
   identical on all six configurations and the milestone stayed whole. The coach did not know the
   answer; it noticed the evidence was one category short of the conclusion.
4. **Ask for a control on a null result.** "Nothing changed" from a binary that did not recompile
   is the expensive kind of wrong.
5. **Verify before accusing** — and prefer not accusing. Both branches had landed on `main`
   against cards saying that was the human's job; the transcripts showed the human had authorised
   it an hour earlier.
6. **Retract in one message and do not defend the error.**
7. **Match permission modes**, or every order waits on a human click.
8. **Ship the command, not the conclusion.** Day 2: the coach said two file sets were disjoint —
   and *both* workers re-measured it themselves before trusting it (`comm -12` before the rebase,
   `merge-base --is-ancestor` before the land). That is the right reflex and the coach should feed
   it: send the number **with the command that produced it**, so re-running is cheaper than
   believing. It is also what made "do not enter the rebase braced for a conflict" safe to send at
   all, after the coach had predicted that same conflict wrongly twice.
9. **Pacing belongs to the human — but a re-issue is not a nudge.** Do not push an idle worker
   because it is idle. *Do* re-issue an order a worker stopped short of: void2d stopped after P2's
   first commit having already named its own next step, and one re-issue moved it through the
   whole half. Day 1 has the same shape at 21:40. The distinction is whether an order is already
   outstanding.

## Create the cause, do not ban the pattern — day 2, the human's correction

The coach proposed a rule: *"a number that ships with an explanation instead of a reproduction is
a defect."* The human rejected the framing, and was right. A prohibition treats a **result**. The
question worth asking is what is **missing from the workflow** that makes the result likely.

The case: `baseline.json` carried `1.63 ms` with a note blaming a busy box. Re-measured on a
verified-idle box with the binary of the very commit that produced it, it read `2.51`. A second
number, `17.8`, read `19.9`. Neither survived. Then void3d found the same shape in its own doc —
a frame cost stated as `0.0643 ms, sd 0.0017` against a run at `0.0424`, thirteen recorded sd out.

Nobody broke a rule. Three things were missing:

- **A number had nowhere to record how it was taken.** The excuse lived in a comment *because
  there was no field for conditions*. Give the artifact the fields — box load at measurement
  time, sample count, method (single run or interleaved A/B), the commit whose binary produced
  it — and the honest thing has a home, while an empty field is visible without anyone accusing
  anyone.
- **No moment in the workflow re-takes a number.** Numbers were taken once at a phase's end and
  inherited forever. Make re-measuring the previous phase's anchor **step zero of the next
  phase**. On day 2 that happened only because the coach ordered it; in the template, nobody has
  to remember.
- **Nobody owned a number after its phase ended.** Step zero assigns that owner.

**And say it as an invitation.** Not *"an explanation instead of a reproduction is a defect"* but
**"when you quote a number, quote how you would reproduce it."** Same content, and one of them is
a thing to do.

Note what is *not* forbidden, because a worker got this exactly right and the distinction matters:
changing a threshold to fit a reading is the bad move; **replacing a baseline proven
unreproducible is the required one.** void2d left `warnFactor` at 1.5 and replaced the baseline
the threshold derives from, and said so in three places.

## Carrying findings across arcs — the coach's actual product

The strongest result of day 2 came from no rule at all. The coach put void2d's ghost-baseline
story, with its four numbers, into an order to void3d about something else. void3d then audited
**its own** doc, unasked, and found the same class. One paragraph, one free finding.

So: **carry a finding to the other arc as a story with its numbers, and let that arc decide what
it means for itself.** Do not convert it into a rule, and do not tell the other arc what to do
with it. This is the thing only the coach is positioned to do, it is cheap, and it respects that
the receiving arc knows its own ground better than the coach does.

**The best instance so far went the other way within the hour, and to a different artifact class
entirely.** Told void2d's blind-format story, void3d applied it to its own **card**: it checked
the handoff bar by script rather than by reading, running `git merge-base --is-ancestor <sha> main`
over every SHA the card named, and found **fifteen dead** — the whole M6 commit table was
pre-rebase hashes its own rebase had destroyed. The card still read beautifully and was broken
only where a fresh session actually uses it, at `git show`. Here the new mechanism is **rebase**
and the blind format is the **card**, which records SHAs as though they were immutable. Carried
back to void2d the same hour, it had four of its own. Rule the workers wrote for themselves:
**after every rebase, re-audit every SHA the card names** — one `for` loop. And the test must be
reachability, not existence: a rewritten commit still resolves with `cat-file` until it is
collected, so `cat-file` alone reports clean when it is not. The coach made exactly that mistake
on the first pass.

The same shape holds for harness findings. void2d found its T1 snapshot format was **blind** to a
new mechanism — regenerating on the first red would have frozen a snapshot asserting nothing — so
it taught the format the new mechanism *before* regenerating. That belongs in front of any arc
about to introduce a mechanism its golden format has never seen.

## The coach's own failure mode, which is worse than the worker's

The coach ordered a worker to decide something `docs/VOID3D.md` had already decided. The worker
did not push back — it researched, decided, landed on the same answer the doc held, and committed
it as fresh. The human caught it, not the worker.

**A worker argues with a reviewer and complies with a coach**, so a coach's error propagates
faster and more quietly than its own. Mitigations: read the decision docs in full before saying
anything architectural, and mark which instructions are the coach's so they can be vetoed.

**The one class no worker has ever caught is the decision class** — ordering a decision a doc had
already made. Five of six day-1 errors were caught by workers; that one was caught by the human.
So the carve-out the escalation loop keeps: **executions go out freely, decisions get drafted for
the human.** Opening or reordering a phase, changing scope, overruling a doc, lifting a brief's
prohibition, touching permissions or config.

## Day-2 warning, cheap and expensive: check that the file you are editing is alive

`~/nerdtool/` and `~/nerdtools/` both existed, with byte-identical copies of this file at
different inodes. `~/nerdtool/DEAD-MOVED-TO-nerdtools.txt` says *"Anything saved here is lost."*
The board and the human's own re-entry prompt both carried a note telling the next coach the
shorter path was the correct one — true when written, false within a day of the move. **A
correction recorded once has an expiry date**, exactly like a hash copied from an unlanded branch.

## The card is the coach's — write it, keep it short, dispatch from it

**The worker reads the card, works, and reports. The coach writes the card.** A worker never
edits it. This frees the worker's context for the arc and puts every arc's state in one hand.

### What a card contains, and nothing else

    Goal        one sentence: what this arc delivers
    Done when   a condition a session can RUN, not judge
    State       one paragraph: the step in flight, and what is owed before the next
    Next        ordered steps, each one a session can start without asking
    Neighbours  what couples this arc to another, and to which

Keep it under a page. A card that grows past that has stopped being a dispatch surface and
become a record; move the record into the repo's tracked docs, where every agent can read it
and a review can catch it.

### End every order with the report you need

    Report: what changed, what you learned that is not in the code, what is still open.

That report is the only input you have. Ask for it in the order, not afterwards.

### On every report, update the card before sending the next order

1. Rewrite **State** and **Next** from the report. Delete what is done; do not append.
2. Add what the worker learned that no artifact carries — a rejected number, an abandoned
   approach, a trap that cost it a run.
3. Re-audit every commit reference the card names, **from inside the worktree**:

        for s in $(grep -ohE '\b[0-9a-f]{7,40}\b' <card> | sort -u); do
          git merge-base --is-ancestor "$s" HEAD || echo "UNREACHABLE $s"
        done

   Run it anywhere else and it prints empty for the wrong reason. Compare against `HEAD`, not
   `main`: unlanded commits are not ancestors of `main`. Use `merge-base`, not `cat-file -e`:
   a rewritten commit still resolves until it is collected.
4. An unreachable reference is either rewritten or in flight. Rewritten: find its replacement
   by subject and **delete the old one outright**, including inside a sentence explaining that
   it is dead — a card that keeps `old -> new` notes re-injects dead hashes into the text this
   loop greps. In flight: name it by **subject**, never by sha.
5. Where the card says numbers were measured at a commit, anchor to the **tree** instead:
   `git rev-parse HEAD^{tree}`, found again with `git log --format='%T %h %s'`. A force push
   rewrites every sha at once; the tree survives.

### Before a worker is replaced

6. Leave the rebase **undone** and say so in **State**, with the reason. A rebase rewrites every
   reference the card names, so it belongs to the next session's first act with the references
   fixed in the same beat. Write it as a decision or the successor reads it as neglect.
7. Name in **Next** any step where partial work moves the number by zero — two independent
   causes, closing one changes nothing. Without it a successor reads correct progress as failure.
8. Strip anything the successor cannot resolve: a slash-command, a tool by its Claude name, a
   harness behaviour. Say what to do, not which button to press.

## Open questions — measure, do not argue

Day-1 figures are **self-graded by the coach**, the circularity the coach criticises elsewhere.
The ledger is the fix, and day 2 added columns for it.

| question | metric | what the answer changes |
|---|---|---|
| Does coaching pay for itself? | interventions that changed an outcome ÷ sent. Day 1: 1 of 6, self-graded. Day 2: ~1 of 4, still self-graded | below ~1 in 5, the coach should only dispatch and connect |
| What does a check cost? | tokens per check, per channel, **instrumented** — every figure so far is an estimate | cheap ⇒ check more often; not ⇒ subscribe instead |
| Is the coach a net source of defects? | coach errors ÷ orders, and **who caught it** — now a ledger column | if workers never catch a class, that class needs the human |
| What does it cost the **human**? | minutes spent, per worker per day — now a ledger column. Day 1 ~25 approvals; day 2 **2 escalations** | the scarcest budget; the escalation loop is the first thing that moved it |
| How long until a wrong turn is noticed? | time from divergence to detection | long ⇒ the gate is the wrong granularity |
| What is worker utilisation? | working ÷ wall-clock. Day 1: 1h36m and 57m of 8h; both idled ~6h40m | under ~50% the bottleneck is the harness, not the agent |
| What do the review passes miss? | classes, not counts. Day 1: 13 findings across two passes, none noticing void3d had **no ms/frame measurement at all** | a recurring miss belongs in the review brief, not in coach habits |

## Untested

More than two workers · a coach across machines · a coach allowed to block a milestone rather
than leaving the verdict to the worker's review loop · the escalation loop under a human who is
away from the keyboard rather than at it.

**A coach surviving its own restart** has a ritual and now three results: `/coach-handoff` flushes
the board and the ledger before a clear and emits the re-entry prompt. Three re-entries have
re-derived the picture from board + ledger + cards alone without asking a worker anything. The gap
those exposed is not in the files but in the **prompt the human re-types**, which carried both a
retired practice and a dead path.
