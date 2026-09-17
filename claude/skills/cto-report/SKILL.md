---
name: cto-report
description: Report on a requested subject to the user in CTO mode — business-first answer, one bridging visual, then stop. Use when the user types /cto-report with a subject, or asks for a status, decision, or findings brief framed for a technical CTO who sets direction and carries the detail himself.
---

# /cto-report

Report on whatever the user asks about, **briefed for a technical CTO**. The user sets direction and design intent across many projects; you carry the file-level detail. He should read your report once, know what's happening at the product level, see one visual that connects it to the system, and then choose whether to drill down. If he has to ask "so what does this actually mean?" — the report failed.

This is a **reporting discipline**, not a tool. It shapes the *form* of your answer. The subject can be anything: a deploy status, a refactor's state, research findings, a bug post-mortem, a branch's ship-readiness, an architecture decision.

## Usage

```
/cto-report <subject>      # report on the named subject
/cto-report                # report on the current task in context
```

No flags. The argument is the subject to report on.

## The output contract — the default shape

Three parts, in order. Resist adding a fourth.

1. **One sentence answering the business question.** What changes for the user / the product / the team. No internals yet. If the answer is "search is now live on the existing embeddings," say exactly that — not the algorithm, not the file paths.

2. **One small visual that bridges business → code.** A before/after, a flow diagram, an option table, a status matrix. Just enough that he can *see* how the business answer touches the system. Not a tutorial, not a diagram of internal modules.

3. **Stop.** Wait for him to pull a thread. Drill into algorithms, file paths, LOC, edge cases **only when he asks**.

## Scale the format to the stakes, not the effort

| Situation | Shape |
|---|---|
| Trivial (name choice, yes/no, status check) | **One line.** No headers, no bullets, no visual. |
| Standard report | The 3-part shape above. |
| Decision needed | Lead with the **shape + trade-off + recommendation**: "Option A (low risk), Option B (cleaner, higher risk). I lean A because …" then stop. One real decision question — never four stacked at the same depth. |
| Confusion at product level ("là sao", "I don't get it", "wait what") | **Zoom OUT, don't re-explain.** Re-frame the *question* ("what should this look like for the user?"), recover the shared mental model first. Tech detail on top of product confusion is noise that compounds. |

## Principles

- **Business-first opening, always.** Open with what it means for the product/user/team — never with `src/foo.ts:343`.
- **Lead, don't bury.** If the real answer is one sentence, it goes first — not after 100 lines of build-up.
- **Do the synthesis yourself.** Don't hand the user a pile of options at equal depth and make him choose blind. Recommend, then let him override.
- **The first visual bridges to business.** A diagram of internal modules is fine *after* he asks; the first one answers "what does this change for the user/team?"
- **Quote his load-bearing framing verbatim** when the subject touches project philosophy — don't paraphrase his phrases into something blander.

## Anti-patterns (these mean the report failed)

- **Tech-first opening** — forces him to load files before he knows if the topic is his concern.
- **Burying the lead** under exposition.
- **Visuals that describe code** instead of bridging to business.
- **Stacking 4 questions** at the same depth without a recommendation — pushes synthesis back onto him.
- **Pasting a 60-line diff and asking "OK?"** — he can't form an opinion without knowing what it's *trying* to do.
- **Headers + sections for a one-line answer** — format must match stakes.

## Template (standard report)

```
<one business sentence — what changed / what's the state, for the product>

<one visual — pick the kind that fits:>
  before/after:   was X → now Y
  status matrix:  | item | state |
  flow:           A → B → C
  options:        Option A (tradeoff) / Option B (tradeoff), I lean ___

<stop — optionally one line: "Drill into any of these?">
```

## What you must do when invoked

1. **Identify the subject.** From the argument, or the current task in context if no argument.
2. **Gather only what the report needs.** Read files, check git, run a status command — but do the gathering silently; the report is the output, not the investigation log.
3. **Decide the stakes** → pick the format (one line / 3-part / decision shape).
4. **Write business-first.** One sentence on what it means, one bridging visual, stop.
5. **Do NOT** open with file paths, dump raw tool output, stack unsynthesized questions, or pad a trivial answer with structure.

The bar, restated: one read → product-level understanding → one visual connecting to the system → his choice whether to drill down.
