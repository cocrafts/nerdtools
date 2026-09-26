---
name: worktree-relaunch
description: End a worker session at a chunk boundary and hand its worktree to a fresh session. It rewrites the card as a lean State, writes a one-generation handoff file with the session's hot memory, and gives the kickstart line. Use when the user types /worktree-relaunch, after a sizable chunk of an arc is committed or landed, when a design question has gone to the person, or when the context passes roughly 300k tokens. Requires a workspace that opts into ~/nerdtools/claude/playbooks/worktree.md.
---

# worktree-relaunch — a fresh session for each chunk of an arc

A session does its best work in roughly its first 300k tokens. After that, early facts compete
with a long tail of tool output, a compaction summarizes what it cannot judge, and the session
starts to re-derive or misremember. An arc outlives its sessions:

- **code and commits** hold what was done;
- **tracked docs** hold what is known;
- **the card** holds where we are;
- **one handoff file** carries what the last session knew that is too hot to keep.

So relaunch on purpose at a chunk boundary, instead of letting the context decay into a compaction.

**When:**
- a chunk is committed or landed;
- a design question went to the person, and the session would otherwise idle on a large context;
- the context is past ~300k tokens, or has already been compacted once;
- before a long investigation in a session that is already heavy.

**Not mid-step.** Finish or revert the step first.

## Where each kind of knowledge goes

| kind | lives in |
|---|---|
| what was done | commits and code — `git log` answers it |
| what is known: measured numbers, rejected approaches, why this shape | tracked docs (`playbooks/documentation.md`: a card is not a doc); the card holds them only until close-out, marked to move |
| where we are: goal, done-when, landed ranges, closed paths, questions waiting on the person, next step | the card |
| hot memory: local artifacts (caches wiped or warm, jobs still running), machine conditions, traps met this session, probe code from a scratch dir, the person's recent words, what not to trust | `<card root>/handoff/<name>.md` |
| a lesson that holds beyond this arc | memory, under the memory rules |

The test for each line: will it still be true, and still matter, after the next session? If yes,
it goes in the card, docs or memory. If it is true now and stale a generation later, it goes in
the handoff.

## Steps

1. **Re-read the rules, in order:**
   - the global `CLAUDE.md`;
   - the repository's `CLAUDE.md`;
   - the workspace `CLAUDE.md`;
   - `playbooks/worktree.md` and `playbooks/documentation.md`.

   Write to today's rules, not to your recall of them. Card location and required lines (a
   `Repo:` paragraph, `Layer`/`Kind`/`Mechanism`) differ by workspace.

2. **Settle the tree:**
   - Commit finished steps through the repository's commit procedure. Revert or finish a half step.
   - Stop every background job, or name it in the handoff with its process, path and output file.
     The next session cannot see a job it did not start. On Windows, kill the whole process tree.
   - Remove probe dirs that the gate would read as changed paths.
   - `git status --short` is clean, or every leftover is named in the handoff.

3. **Rewrite the card. Overwrite it, never append.**
   - **Goal and Done when:** keep the person's words. Strike done items (`~~…~~`). Mark dropped
     items with the reason.
   - **State:** write it for a reader who has seen none of the arc:
     - what landed, as sha ranges with a few words each;
     - the current measured baseline, with its date and conditions (idle or shared machine);
     - closed paths: what was tried and the number that killed it, one line each;
     - questions waiting on the person, each with the fact it rests on;
     - the next step, startable without opening another file.
   - **Neighbours:** only live ones. Check that each branch and card still exists.
   - **Cut:** session narrative, step-by-step history, anything grep or `git log` answers, and stage codes.
   - **Size:** the context hook prints the whole card at every session start, so aim for about
     120 lines. When over, drop history (git has it) and move findings toward docs.

4. **Write the handoff.** Overwrite `<card root>/handoff/<name>.md`, where `<card root>` is the
   directory that holds the card. It lives for one generation. The subdirectory keeps it out of
   every tool that reads `<card root>/*.md` as cards.
   - The first line: what is in flight now, and what the next session must not start without the person.
   - Local state that is not in git: outputs deleted, caches cold or warm, the candidate built and
     at which sha, jobs running and where they write.
   - Machine conditions that decide whether a number is comparable.
   - Traps met in this session, each with the rule that avoids it.
   - Probe code that lived in a session scratch dir, inlined, since the scratch dir dies with the session.
   - The person's recent words and preferences picked up this session, verbatim where the wording matters.
   - What not to trust.

5. **Acceptance test.** From the card and the handoff alone, answer:
   - What is the goal, and how far along is it?
   - What is the next step, and what does it need?
   - What is waiting on the person?
   - What local state would surprise a fresh session?

   Every question you cannot answer is a hole. Go back to step 3 or 4.

6. **Report.** Three lines at most, then the global git line (it names the card and the handoff
   as edits outside the repo), then the kickstart line. It carries no prompt:

       cd <worktree>; claude

   The person opens it and says "continue". Do not clear or exit on the person's behalf.

## The receiving session

`wt.sh context`, the session-start hook, prints the handoff when one exists, then the card.
The receiving session:
1. states the step in flight in one sentence;
2. verifies each local-state claim it will rely on, which is cheap (`git status`, the named paths);
3. deletes the handoff once its first step is under way, not at start: a crash in the first
   minutes would otherwise lose it.

If the handoff and the card disagree about what is in flight, the card wins.

## Traps

- **Appending to State.** The card grows into a transcript nobody reads. One reached 331 lines
  before this skill; the rewrite that replaced it was 90.
- **Hot memory in the card.** Cache state, machine load and pids go stale and mislead sessions
  generations later.
- **A durable decision only in the handoff.** It dies with the file.
- **A kickstart prompt.** The hook already prints the handoff and the card. A prompt that restates
  either one drifts from it.
- **A handoff left behind.** The hook prints it at every session start until someone deletes it,
  so a stale one misleads each later session. The receiving session deletes it.
- **Relaunching while a background job still runs, without saying so.** The next session either
  duplicates it or measures on top of it.
- **Session names and pids as addresses.** Identify work by its path. Processes die.
