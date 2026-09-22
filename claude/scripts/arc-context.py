import json, os, re, subprocess, sys, tempfile

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

INLINE_LIMIT = 150
HOME = os.path.realpath(os.path.expanduser("~"))


def coached_workspace(cwd):
    d = os.path.realpath(cwd)
    while True:
        if os.path.isdir(os.path.join(d, ".coach")):
            return d
        if d == HOME:
            return None
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def run(args):
    out = subprocess.run(args, capture_output=True, text=True, timeout=10)
    return out.stdout.strip() if out.returncode == 0 else ""


def card_path(ws, cwd, name):
    here = os.path.join(ws, ".wt", "%s.md" % name)
    if os.path.isfile(here):
        return here
    main = run(["git", "-C", cwd, "worktree", "list", "--porcelain"]).splitlines()
    if main and main[0].startswith("worktree "):
        there = os.path.join(main[0][len("worktree "):], ".cards", "%s.md" % name)
        if os.path.isfile(there):
            return there
    return here


def section(text, name):
    m = re.search(r"^##+ %s\b.*?(?=^##+ |\Z)" % name, text, re.M | re.S)
    return m.group(0).rstrip() if m else ""


def inline(path):
    text = open(path, encoding="utf-8").read()
    lines = text.count(chr(10)) + 1
    if lines <= INLINE_LIMIT:
        print(text.rstrip())
        return
    print("(%d lines — past a page, so it is not inlined whole; read the file.)" % lines)
    print("")
    st = section(text, "State")
    if st:
        print(st)
        return
    print(chr(10).join(text.splitlines()[:40]).rstrip())
    print("")
    print("Sections: " + ", ".join(re.findall(r"^##+ (.+)$", text, re.M)[:20]))


def emit_card(path):
    if not os.path.isfile(path):
        print("ARC CARD: none at %s — this worktree has no card yet." % path)
        return
    print("ARC CARD for this worktree: %s" % path)
    print("You and the coach both write it. Edit your own sections in place, re-read it")
    print("immediately before writing, never write the file whole.")
    print("")
    inline(path)


def emit_coach(ws):
    coach = os.path.join(ws, ".coach")
    board = os.path.join(coach, "%s.md" % os.path.basename(ws))
    reentry = os.path.join(coach, "reentry.md")
    print("You are the coach for %s, standing in its .coach directory." % ws)
    print("Practice: ~/nerdtools/claude/playbooks/coach.md")
    print("Ledger:   %s — append-only, the history lives there" % os.path.join(coach, "log.tsv"))
    print("Rules:    %s" % os.path.join(ws, "CLAUDE.md"))
    print("Then list your peer sessions, and read the card of every worker still alive.")
    print("Do not read worker transcripts unless the board says an arc is behind.")
    print("")
    if os.path.isfile(reentry):
        print("HANDOFF %s — written by the previous coach, read it before the board:" % reentry)
        print("")
        inline(reentry)
        print("")
    if not os.path.isfile(board):
        print("BOARD: none at %s yet." % board)
        return
    print("BOARD %s — yours, overwritten, never appended:" % board)
    print("")
    inline(board)


def already_said(sid, key):
    if not sid:
        return False
    d = os.path.join(tempfile.gettempdir(), "claude-arc-context")
    f = os.path.join(d, re.sub(r"[^A-Za-z0-9_-]", "_", sid))
    try:
        if os.path.isfile(f) and open(f, encoding="utf-8").read().strip() == key:
            return True
        os.makedirs(d, exist_ok=True)
        open(f, "w", encoding="utf-8").write(key)
    except Exception:
        pass
    return False


def main():
    data = json.load(sys.stdin)
    cwd = data.get("cwd") or os.getcwd()
    ws = coached_workspace(cwd)
    if not ws:
        return
    sid = str(data.get("session_id", ""))
    repeatable = str(data.get("hook_event_name", "")) == "SessionStart"
    if os.path.realpath(cwd) == os.path.realpath(os.path.join(ws, ".coach")):
        if repeatable or not already_said(sid, "coach"):
            emit_coach(ws)
        return
    m = re.match(r"^wt/(.+)$", run(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"]))
    if m and (repeatable or not already_said(sid, m.group(1))):
        emit_card(card_path(ws, cwd, m.group(1)))


try:
    main()
except Exception as e:
    print('arc-context: %s: %s' % (type(e).__name__, e), file=sys.stderr)
sys.exit(0)
