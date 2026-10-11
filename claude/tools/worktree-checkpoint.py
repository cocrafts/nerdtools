import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("card_state", TOOLS / "card-state.py")
card_state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(card_state)


def staleness(cwd):
    found = subprocess.run(["bash", str(TOOLS / "wt.sh"), "snapshot"], cwd=cwd, env={**os.environ, "WT_CWD": cwd}, capture_output=True, text=True, timeout=20)
    if found.returncode:
        raise ValueError(found.stderr.strip() or "worktree snapshot failed")
    data = json.loads(found.stdout)
    return None if data is None else card_state.stale(data)


def main():
    event = json.load(sys.stdin)
    name = event.get("hook_event_name")
    if name == "PreCompact":
        if event.get("trigger") == "auto":
            return
        reason = staleness(event["cwd"])
        if reason:
            raise ValueError(f"{reason}. Ask this session to update its card, then /compact again.")
    elif name == "SessionStart":
        if event.get("source") != "compact":
            return
        reason = staleness(event["cwd"])
        if reason:
            print(f"Compaction ran before the card was checkpointed: {reason}. Before other work, overwrite that State from the summary above, labelling transcript-reported results as unverified.")
    else:
        raise ValueError(f"unsupported hook event: {name}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Worktree checkpoint: {error}", file=sys.stderr)
        sys.exit(2)
