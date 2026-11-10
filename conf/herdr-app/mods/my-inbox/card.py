# The focused session's worktree card State and its handoff, for the my-inbox panel. Runs as
# `python3 -c` on the pane's machine.
#   argv: the pane's foreground pid, the pane's cwd, the key read last time
# Prints {"same": true} when neither file changed since that key, {"none": why} when the
# folder has no card, else {"key", "name", "card", "state", "handoff", "delivered", "handoff_mtime"}.
import json, os, subprocess, sys

pid, pane_cwd, last = (sys.argv[1:] + ["", "", ""])[:3]


def out(**kw):
    print(json.dumps(kw))
    sys.exit()


# The process's own folder: the one the pane reports follows the last `cd` an agent's
# shell tool ran, which is often another repo.
def process_cwd():
    try:
        return os.readlink(f"/proc/{pid}/cwd")
    except OSError:
        pass
    try:
        r = subprocess.run(["lsof", "-a", "-p", pid, "-d", "cwd", "-Fn"], capture_output=True, text=True, timeout=5)
        return next((l[1:] for l in r.stdout.splitlines() if l.startswith("n")), None)
    except (OSError, subprocess.SubprocessError):
        return None


cwd = (pid and process_cwd()) or pane_cwd
if not cwd or not os.path.isdir(cwd):
    out(none="no folder for this pane")
# A repo's own tools/wt.sh, sourced by the shared one, reads the folder it runs in.
wt = os.path.expanduser("~/nerdtools/claude/tools/wt.sh")
r = subprocess.run(["bash", wt, "card"], cwd=cwd, env={**os.environ, "WT_CWD": cwd}, capture_output=True, text=True, timeout=15)
if r.returncode != 0:
    out(none=(r.stderr.strip().splitlines() or ["no card"])[-1].removeprefix("wt: "), cwd=cwd)
path, _, card = r.stdout.partition("\n")
name = os.path.basename(path)[: -len(".md")]
root = os.path.dirname(path)
live, delivered = f"{root}/handoff/{name}.md", f"{root}/handoff/delivered/{name}.md"
handoff = live if os.path.isfile(live) else delivered if os.path.isfile(delivered) else None
key = f"{path}:{os.path.getmtime(path)}:{handoff}:{handoff and os.path.getmtime(handoff)}"
if key == last:
    out(same=True)

state, inside = [], False
for line in card.splitlines():
    if line.startswith("## "):
        inside = line[3:].strip().lower() == "state"
    elif inside:
        state.append(line)
out(
    key=key,
    name=name,
    card=path,
    state="\n".join(state).strip(),
    handoff=open(handoff, errors="replace").read().strip() if handoff else None,
    delivered=handoff == delivered,
    handoff_mtime=handoff and os.path.getmtime(handoff),
)
