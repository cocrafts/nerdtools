#!/usr/bin/env python3
"""Usage: session-metrics.py <project-path> [recent-N] [--split YYYY-MM-DD] [--since YYYY-MM-DD]
e.g. session-metrics.py ~/metascript/recompiler 30
     session-metrics.py ~/metascript/recompiler --since 2026-09-01 --split 2026-09-19"""
import json, os, sys, glob, statistics
from datetime import datetime, timezone

WORKING_SESSION_MIN_TURNS = 3
LONG_SESSION_TURNS = 35

def when(o):
    try: return datetime.fromisoformat(o["timestamp"].replace("Z", "+00:00"))
    except Exception: return None

def user_text(content):
    if isinstance(content, str): return content
    if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in content): return None
    return " ".join(b.get("text", "") for b in content if isinstance(b, dict))

MACHINE_PREFIXES = ("<", "[", "/", "Base directory for this skill", "Caveat:", "Human:", "Assistant:")
SCRIPTED_ENTRYPOINTS = ("sdk-ts", "sdk-cli", "sdk-py")

def typed_by_person(o, text):
    return not o.get("isMeta") and not o.get("isSidechain") and not text.lstrip().startswith(MACHINE_PREFIXES)

def events(path):
    pending, last = {}, None
    for line in open(path, encoding="utf-8", errors="replace"):
        try: o = json.loads(line)
        except Exception: continue
        if o.get("entrypoint") in SCRIPTED_ENTRYPOINTS: continue
        t = when(o) or last
        last = t
        if t is None: continue
        content = (o.get("message") or {}).get("content") or []
        if o.get("type") == "assistant":
            for b in content:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    pending[b.get("id")] = t
                    yield t, "tools"
        elif o.get("type") == "user":
            text = user_text(content)
            if text is None:
                for b in content:
                    start = pending.pop(b.get("tool_use_id"), None) if isinstance(b, dict) else None
                    if start and (t - start).total_seconds() > 300: yield t, "slow"
            elif "continued from a previous" in text or "This session is being continued" in text: yield t, "compactions"
            elif "Another Claude session" in text: yield t, "cross"
            elif text.strip() and typed_by_person(o, text): yield t, "turns"

def scan(path):
    row = dict(turns=0, compactions=0, tools=0, slow=0, cross=0)
    first = last = None
    for t, kind in events(path):
        row[kind] += 1
        first = first or t; last = t
    row["hours"] = (last - first).total_seconds() / 3600 if first and last else 0
    return row

def stores_of(project):
    store_of = lambda path: os.path.expanduser("~/.claude/projects/" + path.replace("/", "-").replace(".", "-"))
    parent, repo = os.path.split(project.rstrip("/"))
    wt_root = os.environ.get("MSC_WT_ROOT") or os.path.join(parent, ".wt")
    main = store_of(project)
    worktrees = []
    if repo == "recompiler":
        worktrees += glob.glob(store_of(os.path.join(wt_root, "wt-")) + "*")
    worktrees += glob.glob(store_of(os.path.join(parent, repo + "-wt-")) + "*")
    return main, [main] + worktrees

def recent(project, stores, limit):
    files = sorted((f for s in stores for f in glob.glob(s + "/*.jsonl")), key=os.path.getmtime, reverse=True)
    rows = []
    for f in files:
        row = scan(f)
        if row["turns"] >= WORKING_SESSION_MIN_TURNS: rows.append(row)
        if limit and len(rows) == limit: break
    n = max(len(rows), 1)
    total = lambda k: sum(r[k] for r in rows)
    print(f"{project}  sessions={len(rows)}")
    print(f"  user turns/session      {total('turns')/n:.0f}")
    print(f"  compactions/session     {total('compactions')/n:.2f}")
    print(f"  tool calls/user turn    {total('tools')/max(total('turns'),1):.1f}")
    print(f"  bash >5min/session      {total('slow')/n:.1f}")
    print(f"  cross-session msgs      {total('cross')}")
    print(f"  median session hours    {statistics.median([r['hours'] for r in rows] or [0]):.1f}")

def day(text):
    return datetime.strptime(text, "%Y-%m-%d").replace(tzinfo=timezone.utc)

def by_period(project, main, stores, since, split):
    names = ["before", "after"] if split else ["all"]
    totals = {p: dict(turns=0, compactions=0, tools=0, slow=0, cross=0, wt_turns=0) for p in names}
    per_session = {p: [] for p in names}
    for store in stores:
        for path in glob.glob(store + "/*.jsonl"):
            counts = {p: 0 for p in names}
            for t, kind in events(path):
                if since and t < since: continue
                p = ("after" if t >= split else "before") if split else "all"
                totals[p][kind] += 1
                if kind == "turns":
                    counts[p] += 1
                    if store != main: totals[p]["wt_turns"] += 1
            for p in names:
                if counts[p] >= WORKING_SESSION_MIN_TURNS: per_session[p].append(counts[p])
    print(f"{project}  since={since.date() if since else 'start'}  split={split.date() if split else '-'}")
    print(f"  {'':34}" + "".join(f"{p:>10}" for p in names))
    def line(label, value):
        print(f"  {label:34}" + "".join(f"{value(p):>10}" for p in names))
    per100 = lambda p, k: f"{100 * totals[p][k] / max(totals[p]['turns'], 1):.1f}"
    turns_of = lambda p: sorted(per_session[p]) or [0]
    line("user turns", lambda p: totals[p]["turns"])
    line(f"working sessions (>= {WORKING_SESSION_MIN_TURNS} turns)", lambda p: len(per_session[p]))
    line("  median turns", lambda p: f"{statistics.median(turns_of(p)):.0f}")
    line("  p90 turns", lambda p: turns_of(p)[int(0.9 * (len(turns_of(p)) - 1))])
    line(f"turns inside sessions > {LONG_SESSION_TURNS} turns %", lambda p: f"{100 * sum(c for c in per_session[p] if c > LONG_SESSION_TURNS) / max(totals[p]['turns'], 1):.0f}")
    line("turns inside a worktree %", lambda p: f"{100 * totals[p]['wt_turns'] / max(totals[p]['turns'], 1):.0f}")
    line("compactions / 100 turns", lambda p: per100(p, "compactions"))
    line("bash > 5min / 100 turns", lambda p: per100(p, "slow"))
    line("cross-session msgs / 100 turns", lambda p: per100(p, "cross"))
    line("tool calls / turn", lambda p: f"{totals[p]['tools'] / max(totals[p]['turns'], 1):.1f}")

def main():
    args = sys.argv[1:]
    flag = lambda name: day(args[args.index(name) + 1]) if name in args else None
    since, split = flag("--since"), flag("--split")
    positional = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] not in ("--since", "--split"))]
    project = os.path.abspath(os.path.expanduser(positional[0]))
    main_store, stores = stores_of(project)
    if since or split: by_period(project, main_store, stores, since, split)
    else: recent(project, stores, int(positional[1]) if len(positional) > 1 else None)

main()
