# Global Claude Code Configuration

Universal guidance for Claude Code across all projects and repositories.

## Git Commits — HARD RULE

**NEVER commit without asking the user first.** No exceptions, no "I'll just commit this quickly." When you think it's time to commit, ask. When the user says commit, use `/split-commit` unless they specify otherwise. This applies to ALL projects, ALL sessions, ALL the time.

## Comments — IMPORTANT

**HARD RULE FROM THE USER (do not relax, do not "earn it back"):** when editing code, do NOT add explanatory comments. Default to ZERO. If a constraint is genuinely load-bearing, encode it in a name, a test, or an assertion — not prose. This applies even to comments that look like "good WHY" — leave them out unless he explicitly asks.

**Never explain WHAT the code does** — well-named identifiers already do that. Never reference the current task/PR/session ("added for X flow", "issue #123") — that belongs in the commit message and rots.

**Anti-pattern**: padding edits with block comments that restate the function's purpose or describe the change you are making. If you write 4+ lines of justification for a 2-line change, the comment isn't earning its keep.

## Skills

When the user types `/<skill-name>`, invoke the Skill tool with that skill **before doing anything else**. The available skills, their descriptions and paths are listed in the harness `<available_skills>` block — do not duplicate that list here.

## Session state and reporting — HARD RULE (audit 2026-09-17: 104 compactions, 312 "where are we" questions in 10 days)

- **State lives in a file, not in the conversation.** Every arc has one `arc_<name>.md` in the project memory dir (`~/.claude/projects/<project>/memory/`), ≤ 40 lines, sections: Mục tiêu / Đã land / Bước hiện tại / Chưa commit / Chặn / Next / Verdict mô hình. Update it after every land, every verdict, and before any long lane. Never rely on the compaction summary to carry state.
- **`/where`** answers "đang làm gì / ở đâu / what next" from that file in ≤ 8 lines. Never rebuild history from the transcript or from memory novels; if the file is stale, fix the file, then answer.
- **Session boundary**: after a land or a milestone, tell the user "file trạng thái đã cập nhật, có thể `/clear`". Do not let a session reach a second compaction.
- **After a lane (suite/guard/corpus/SAN)**: line 1 = verdict with numbers and the diff against the known-red set; then the single next action. ≤ 5 lines, no headers, no tables unless it is an A/B.
- **Background lanes**: launch in the background, report on the notification. The user does not poll.
- **No narrative reports**: no "history", no process retelling, no `★ Insight`, no headers in messages under ~500 words. Never Read a file > 300 lines whole; summarise logs by script to ≤ 20 lines.

## Frontend Component Architecture

**Pattern**: ui/content/layout/features split, NOT strict Atomic atoms/molecules/organisms.
**Trigger**: starting a React/Vue/Svelte project | refactoring `components/` | choosing where a new component lives | asked about Atomic Design.

## Claude Code Hooks

Configured in `~/.claude/settings.json` (NOT hooks.json); scripts in `~/.claude/hooks/entries/`. Use the hook-designer / workflow-architect agents.

## Defaults

- **Tool priority**: MCP first (docs → Ref, search → exa, browser → playwright), then built-ins; document why you fell back. Built-in Read/Write/Edit/Grep/Task are used directly.
- **Code**: follow existing patterns, edit > create, no unsolicited docs, absolute paths, avoid emojis, match surrounding style.
- **Config priority**: project CLAUDE.md → this global → tool defaults → built-in behaviour.
- **Todos**: strikethrough (`~~text~~`) for completed items; in-progress and pending render plain.
- **Voice mode**: `min_listen_duration=5` (prevents cutoffs during pauses).
