---
name: identify-topic
description: Explain a term, concept, or symptom in the context of the current work — what it is, which layer/phase owns it, what it looks like in code, why it matters, and how to close it. Answers "cái X này là gì, nằm ở đâu, sửa kiểu gì?"
---

# Identify Topic

The user hit a term they don't have loaded — `null-deref`, `tail call`, `ARC cycle`, `sigmatch`, `xfail`, `BSATN`, `closure convention`. They want it grounded **in the work at hand**, not a textbook definition.

This is the *explain* counterpart to `/zone-issue-area` (which *classifies a bug*). Same house style, different question:

- `/zone-issue-area` → "what kind of bug is this and how dangerous is the fix?"
- `/identify-topic` → "what IS this thing, where does it live, what does it look like, what do I do about it?"

## Input

`/identify-topic <term or symptom>`. If the term already appeared in the conversation, anchor the answer to **that** occurrence — the concrete file, the concrete crash, the concrete measurement. Never drift into a generic tutorial.

If the term is genuinely ambiguous (`type error`, `it crashes`), ask ONE disambiguating question before answering. Do not answer three interpretations in parallel.

### Mode B — "báo cáo đang làm gì / tới đâu / có bám /trace-nim không?"

Triggered by any of: *"báo cáo mình đang làm gì"*, *"progress tới đâu"*, *"đang làm cái gì vậy"*, *"có bám sát /trace-nim không"*, *"what are we doing right now"*. This is the same skill pointed at **the work in flight** instead of at a term — the user has lost the thread of an arc that has run long, and wants it re-grounded in **user-space** (what a person writing `.ms` sees), not in compiler internals.

Answer with these slots, in this order, and nothing else:

1. **Đang làm gì** — one sentence, in product terms. What changes for someone writing MetaScript when this lands. Not the file, not the pass.
2. **Syntax** — the actual `.ms` the user would type, and **whether it changes**. Three honest outcomes, name which one applies:
   - *no syntax change* — same code, different behaviour (most compiler fixes)
   - *same syntax, new diagnostic* — code that compiled now errors (say what error, and that it's a good thing)
   - *new syntax* — rare; show before/after
3. **Progress** — done / in flight / not started, with the measurement that backs each claim. A step is "done" only if a gate was run; "code written" is *in flight*, not done.
4. **/trace-nim compliance** — explicitly yes/no/partial, with what was actually read. Name the reference file+proc consulted, and state whether our behaviour *matches*, is an *intentional divergence* (cite NIM-REF.md row), or is an *unverified gap*. If the answer is "chưa đọc reference cho phần này" — say that plainly; it's the most useful sentence in the report.
5. **Còn lại** — what's next, and the one decision (if any) waiting on the user.

Rules specific to Mode B:
- **User-space first, internals on demand.** "Compiler sẽ báo lỗi thay vì chạy sai" beats "siết điều kiện `isUnresolvedType(propType)` trong `checkExprPass`". The file path can appear once, at the end of a slot, as an anchor.
- **Separate what was measured from what was assumed** — reuse the fact/assumption split from `/zone-issue-area`. A progress report that presents a hypothesis as progress is worse than no report.
- **Never report a step as done because the code is written.** Gate output or it didn't happen.
- **If the arc drifted from the original objective, say so in slot 1** — "bắt đầu là X, giữa đường lòi ra Y, hiện đang ở Y" is the honest opening, not a hidden reordering.
- Keep it to roughly a screen. This is a re-orientation, not a hand-off document.

## The Five Slots

Every answer fills exactly these, in this order. Anything that doesn't fit a slot gets cut.

### 1. Definition — one sentence, plain

What the thing IS. No jargon that itself needs a lookup. If the term has a general meaning AND a local meaning in this codebase, give the local one and say it's local.

### 2. Location — layer, and phase if it's a compiler thing

Reuse the `/zone-issue-area` vocabulary so the two skills interlock:

- **Layer**: compiler · runtime · stdlib · tooling · platform
- **Phase** (compiler only): Parse · Check · Transform · Analyze · Codegen

Name the actual file/function when one is known. `file:line` — it's clickable.

Crucially: state whether the thing is a **compile-time** or **run-time** phenomenon, and if the symptom appears at a different time than the cause (compile-time construct → runtime crash), say so explicitly. That gap is usually the whole confusion.

### 3. Shape — what it looks like

The concrete syntax or code pattern. Prefer a **before/after** or **source → generated** pair over prose. Keep it under ~12 lines. For codegen topics, show the emitted C/JS, not just the `.ms`.

If the thing has no syntax (it's a phase, a property, a failure mode), show the *smallest reproducer* instead.

### 4. Why it matters — the stake

What breaks, who notices, and how loudly. Rank the failure mode honestly:

- **loud** — build error / diagnostic with a location (cheap; the compiler did its job)
- **crash** — SIGSEGV / stack overflow / abort (annoying but self-announcing)
- **silent** — wrong output, no diagnostic (the expensive one — always call this out)

If it's silent, say so first and explain what the wrong output looks like.

### 5. How to close it — direction, not a patch

The fix *shape* plus its blast radius. One recommended direction; name alternatives only if a real decision exists, and then recommend one. Flag if the fix is a separate arc from what's currently in flight.

If the honest answer is "leave it, here's the workaround" — say that.

## Output Format

Match the conversation's language for prose. Keep technical tokens (`compiler`, `Transform`, `null-deref`, file paths, identifiers) in English — they're greppable tags, not narration.

Lead with the one-sentence definition. Then the slots. Then stop.

Shape:

```
**<term>** — <one sentence definition>.

Tầng / Layer:   <layer> · <phase if compiler> · <compile-time | run-time>
Nơi ở / Site:   <file:line or module>

<shape: a small before/after or source→generated block>

Ý nghĩa:        <stake, with loud|crash|silent named>
Hướng đóng:     <fix shape + blast radius, one recommendation>
```

Rules of thumb:
- No boxes, no ASCII frames — they wrap ugly in narrow terminals.
- One code block maximum. If two feel necessary, the second one is probably explaining something the user didn't ask.
- Don't restate what the user already demonstrated they know.
- If the topic is currently in flight in this session, end with one line on its live status (fixed / open / measured-not-fixed) — no more.

## Rules

- **Ground it in the session.** If we crashed on this thing an hour ago, that crash IS the example. A synthetic example when a real one exists is a wasted answer.
- **Don't investigate.** If answering needs a measurement, say which measurement and offer to run it — don't silently go do a 20-minute probe.
- **Separate the term from the instance.** If the general concept and our specific occurrence differ, name both and say which one the user is looking at.
- **Never pad.** Five slots, short. If a slot has nothing real in it, drop the slot rather than filling it with filler.
- **Uncertainty is content.** "This is the general meaning; whether OUR case is that shape is unverified" is a legitimate and useful answer.
