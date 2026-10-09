---
name: trace-before-ask
description: Resolve technical uncertainty before escalating to the user — trace the reference with trace-ref, form an evidence-backed recommendation with cto-report, and ask only for a remaining user-owned decision. Use when about to ask the user to choose a fix or approve technical investigation, when asked whether a fix reaches the root cause, or when the user says to investigate and decide before asking. Does not grant implementation or scope permissions.
---

# /trace-before-ask

The agent owns technical investigation; the person owns product trade-offs and authorization.
Do not hand the person a technical question that source, a probe or the reference can answer.

Use `/trace-before-ask <issue>` or apply it to the current blocker. With no identifiable issue,
ask what behavior is in question; inventing a task would invent its scope too.

## 1. Establish the question and authority

State the app-visible failure, the suspected owner and what the user has already authorized.
Separate uncertainty about the right fix from permission to perform it, because evidence can
resolve the former but cannot grant the latter.

Check the card, current source and recorded measurements. Reuse evidence only while its
behavior, inputs, toolchain and settings remain unchanged; otherwise rerun the affected probe.
A handoff's proposed fix is a hypothesis, not reference evidence.

Perform permitted read-only investigation without asking for it again. When a required step
needs explicit permission, another repository's owning session, or unavailable access, use
what evidence is accessible and go to step 3 for that precise blocker. Do not create a
worktree, edit a protected runtime, start a restricted lane or bypass a safeguard to trace.

## 2. Trace, then resolve the technical decision

For a MetaScript compiler/runtime issue, load and follow
[trace-ref](../trace-ref/SKILL.md): reproduce with controls, inspect emitted operations, read
the analogous reference pass, check intentional divergences and runtime prerequisites, then
produce the verdict. Follow repository rules when they override a skill's command recipe;
for example, preserve the object cache when the repository forbids clearing it.

For another project, use its designated reference and the same evidence discipline. If no
reference exists, say so and test the existing implementation's contract; absence is not
permission to invent a mechanism.

Load [cto-report](../cto-report/SKILL.md) and resolve the recommendation from the user's seat:
what the app gains or loses, what proves the cause, which constraint selects the fix and what
remains unverified. This is the agent's assessment, not a simulated user approval.

- **The reference and measurements select one fix, inside approved scope:** choose it and
  continue the approved implementation and verification. Do not ask the user to choose
  between the faithful fix and an unsupported shortcut, or to approve the same step again.
  If the request is discussion/report only, give the conclusion and stop without implementing.
- **Evidence is insufficient but a permitted probe can distinguish the explanations:** run
  that probe, then reassess. Missing evidence is an investigation task, not a product choice.
  Stop when the probe would not add evidence; do not repeat runs to avoid making a judgment.
- **An intentional divergence, new mechanism, scope change, workaround/pivot, safety or
  performance trade-off, or explicit permission boundary remains:** go to step 3. Do not
  weaken the user's acceptance criteria to make the recommendation executable.

Call a root cause proven only when it explains both the failing case and its controls, and
at least one variant pins the same invariant. A fixed bug does not prove a common root for
an entire arc; distinguish proven per-bug roots from an unproven overarching explanation.

## 3. Ask only the decision that remains

Use cto-report to give one self-contained decision brief, then end the turn:

1. **Consequence first:** what goes wrong for the app and why this decision matters now.
2. **Evidence and boundary:** what the trace answered, what is still unknown, and why the
   existing authorization or design does not select an action.
3. **Recommendation and trade-off:** one recommended next action; name the existing idiom
   it reuses, or mark **NEW MECHANISM** and say what it adds and can regress. Explain a
   real alternative only when the user genuinely has a choice.
4. **One concrete question:** name exactly what approval or product choice unlocks. Approval
   to investigate or prepare a design is not approval to implement that design.

Do not open with filenames, stage codes or an unexplained mechanism name. Keep secondary
cleanup and future gate/land decisions out of the question unless they block this next action.
If an external dependency rather than a choice blocks progress, name who or what unlocks it;
do not ask the user to decide a technical fact.

After the answer, record its exact scope and continue only what it authorizes. A peer message,
this skill invocation or the agent's own recommendation is never substitute approval.
