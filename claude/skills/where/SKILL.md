---
name: where
description: Answer "đang làm gì / đang ở đâu / arc lớn là gì / what next" from the arc state file in ≤ 8 lines. Use when the user types /where or asks any variant of those questions (sao rồi, tình hình, reminds lại, báo cáo trạng thái).
---

# /where — trạng thái từ file, không từ trí nhớ

The state of an arc lives in ONE file: `~/.claude/projects/<project>/memory/arc_<name>.md`
(≤ 40 lines; sections Mục tiêu / Đã land / Bước hiện tại / Chưa commit / Chặn / Next / Verdict mô hình).
The conversation is not the source of truth; the compaction summary is not either.

## Steps

1. `ls -t ~/.claude/projects/<project>/memory/arc_*.md | head -3` — take the newest, or the one the
   user names. `<project>` is the current project's memory dir (the one in your system prompt).
2. Read it. If it is stale (a land or verdict happened this session that it does not record),
   update the file FIRST with what you know for certain (git log / git status are the checks),
   then answer.
3. Answer in this exact shape, ≤ 8 lines, no headers, no tables:

```
Arc: <tên arc> — <mục tiêu một câu>
Đã land: <sha ngắn, ngày> …
Đang: <bước hiện tại, một câu>
Chưa commit: <file, của ai> | sạch
Chặn: <gì, ai gỡ> | không
Next: <hành động kế tiếp, một câu>
Verdict mô hình: <SAME / DIVERGE-INTENTIONAL / … kèm một cụm lý do> | chưa trace
File: <đường dẫn arc file>
```

4. Stop. Do not append history, options, or explanations. If the user wants a thread pulled, they ask.

## Never

- Never scan the transcript or read `MEMORY-DETAIL.md` / long project memories to reconstruct state.
- Never answer from the compaction summary alone when an arc file exists.
- If NO arc file exists for the current work: create one from `git log`/`git status` and the plan file,
  say so in one line, then answer from it.
