import json, os, re, subprocess, sys, tempfile

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

WS = os.path.join(os.path.expanduser("~"), "metascript")
INLINE_LIMIT = 150


def under(path, root):
    try:
        return os.path.commonpath([os.path.realpath(path), os.path.realpath(root)]) == os.path.realpath(root)
    except Exception:
        return False


def branch(cwd):
    out = subprocess.run(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"],
                         capture_output=True, text=True, timeout=10)
    return out.stdout.strip() if out.returncode == 0 else ""


def section(text, name):
    m = re.search(r"^##+ %s\b.*?(?=^##+ |\Z)" % name, text, re.M | re.S)
    return m.group(0).rstrip() if m else ""


def emit_card(name):
    path = os.path.join(WS, ".wt", "%s.md" % name)
    if not os.path.isfile(path):
        print("ARC CARD: none at %s — this worktree has no card yet." % path)
        return
    text = open(path, encoding="utf-8").read()
    lines = text.count("\n") + 1
    print("ARC CARD for this worktree: %s" % path)
    print("You and the coach both write it. Edit your own sections in place, re-read it")
    print("immediately before writing, never write the file whole.")
    print("")
    if lines <= INLINE_LIMIT:
        print(text.rstrip())
        return
    print("(%d lines — past a page, so it is not inlined whole; read the file.)" % lines)
    print("")
    st = section(text, "State")
    if st:
        print(st)
        return
    print(os.linesep.join(text.splitlines()[:40]).rstrip())
    print("")
    print("Sections: " + ", ".join(re.findall(r"^##+ (.+)$", text, re.M)[:20]))


def emit_coach():
    print("You are the coach for ~/metascript. Read, in this order:")
    print("  ~/nerdtools/claude/playbooks/coach.md   the practice")
    print("  ~/metascript/CLAUDE.md  section Coaching")
    print("  ~/metascript/.coach/metascript.md       the board")
    print("  ~/metascript/.coach/log.tsv             the ledger")
    print("Then ListAgents, and the .wt/ card of every worker it lists as alive.")
    print("Do not read worker transcripts unless the board says an arc is behind.")


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
    if not under(cwd, WS):
        return
    sid = str(data.get("session_id", ""))
    repeatable = str(data.get("hook_event_name", "")) == "SessionStart"
    marker = os.path.join(WS, ".coach", "session-id")
    if sid and os.path.isfile(marker) and open(marker, encoding="utf-8").read().strip() == sid:
        if repeatable or not already_said(sid, "coach"):
            emit_coach()
        return
    m = re.match(r"^wt/(.+)$", branch(cwd))
    if m and (repeatable or not already_said(sid, m.group(1))):
        emit_card(m.group(1))


try:
    main()
except Exception:
    pass
sys.exit(0)
