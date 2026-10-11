import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

STATE_LIMIT = 4000
CARD_LIMIT = 8000
def git(cwd, *args):
    return subprocess.check_output(["git", "-C", cwd, *args], text=True).strip()


def identity(cwd):
    return {
        "head": git(cwd, "rev-parse", "HEAD"),
        "tree": git(cwd, "rev-parse", "HEAD^{tree}"),
        "status": git(cwd, "status", "--porcelain=v1", "--untracked-files=normal"),
        "tracked_diff": hashlib.sha256(subprocess.check_output([
            "git", "-C", cwd, "diff", "HEAD", "--no-ext-diff", "--no-textconv", "--binary",
        ])).hexdigest(),
    }


def sections(text):
    spans = {}
    headings = list(re.finditer(r"^## ([^\n]+)\n", text, re.M))
    for index, heading in enumerate(headings):
        name = heading.group(1).strip()
        if name in spans:
            raise ValueError(f"duplicate card section: {name}")
        spans[name] = (heading.end(), headings[index + 1].start() if index + 1 < len(headings) else len(text))
    for name in ("Goal", "Done when", "State"):
        if name not in spans or not text[slice(*spans[name])].strip():
            raise ValueError(f"card requires nonempty ## {name}")
    return spans


def validate(text):
    spans = sections(text)
    state = text[slice(*spans["State"])].strip()
    if len(text) > CARD_LIMIT:
        raise ValueError(f"card has {len(text)} characters, limit {CARD_LIMIT}; owner must shorten it")
    if len(state) > STATE_LIMIT:
        raise ValueError(f"State has {len(state)} characters, limit {STATE_LIMIT}; owner must shorten it")
    return spans


def snapshot(cwd, path):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f"card must not be a symlink: {path}")
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    validate(text)
    return {
        "cwd": str(Path(cwd).resolve()),
        "path": str(path.resolve()),
        "text": text,
        "hash": hashlib.sha256(raw).hexdigest(),
        **identity(cwd),
    }


def stale(data):
    card = Path(data["path"]).resolve()
    written = card.stat().st_mtime
    cwd = Path(data["cwd"])
    changes = [(int(git(data["cwd"], "log", "-1", "--format=%ct")), "the HEAD commit")]
    entries = iter(subprocess.check_output(["git", "-C", data["cwd"], "status", "--porcelain=v1", "-z", "--untracked-files=all"], text=True).split("\0"))
    for entry in entries:
        if not entry:
            continue
        if entry[0] in "RC":
            next(entries)
        path = cwd / entry[3:]
        if path.exists() and path.resolve() != card:
            changes.append((path.stat().st_mtime, entry[3:]))
    changed_at, changed = max(changes)
    if changed_at <= written:
        return None
    return f"State of {card} predates {changed}; overwrite ## State (Verified, In flight, Blocked, Next) before compaction, because a summary cannot reconstruct evidence that was never checkpointed"


def render(data):
    return (
        f"Card of this worktree, {data['path']}:\n"
        "Current card from disk; not new approval or a test certificate. Reconcile summary conflicts "
        "against Git/code/named evidence. Verify local claims needed for Next.\n"
        f"Git observed: HEAD {data['head']}; committed tree {data['tree']}; "
        f"worktree {'dirty' if data['status'] else 'clean'}. "
        "Git observations do not fingerprint untracked contents or external artifacts; verify them before relying on them.\n\n"
        f"{data['text']}"
    )


def main():
    command = sys.argv[1]
    if command in ("strip-context", "checked-context"):
        text = sys.stdin.read()
        match = re.search(r"^Card of this worktree, (.+):\n", text, re.M)
        if match:
            block = match.group(0) + Path(match.group(1)).read_bytes().decode("utf-8")
            if not text.startswith(block, match.start()):
                raise ValueError("card changed while splitting worktree context")
            replacement = render(snapshot(sys.argv[2], match.group(1))) if command == "checked-context" else ""
            text = text[:match.start()] + replacement + text[match.start() + len(block):]
        elif command == "checked-context":
            raise ValueError("worktree context omitted the applicable card")
        print(text, end="")
        return
    if command == "snapshot":
        lines = sys.stdin.read().splitlines() if len(sys.argv) <= 3 else []
        if len(sys.argv) <= 3 and not lines:
            raise ValueError("worktree card locator returned no path")
        path = sys.argv[3] if len(sys.argv) > 3 else lines[0]
        result = snapshot(sys.argv[2], path)
    else:
        data = json.load(sys.stdin)
        if command == "stale":
            result = stale(data)
        elif command == "render":
            result = render(data)
        else:
            raise ValueError(f"unknown card-state command: {command}")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"card-state: {error}", file=sys.stderr)
        sys.exit(1)
