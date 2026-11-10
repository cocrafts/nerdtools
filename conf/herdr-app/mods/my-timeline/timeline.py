# The prompts of one agent's conversation, for the my-timeline panel. Runs as `python3 -c`
# on the agent's machine, so nothing needs installing there.
#   argv: app (claude-code | pi), foreground pid, Pi session id, the key read last time
# Prints {"same": true} when the transcript is unchanged since that key, else
# {"key", "context", "total", "prompts": [{n, at, done, text, tokens, tools, reply}]}.
import glob, json, os, re, sys

app, pid, pi_session, last = (sys.argv[1:] + ["", "", "", ""])[:4]
home = os.path.expanduser("~")


def transcript():
    if app == "claude-code":
        try:
            s = json.load(open(f"{home}/.claude/sessions/{pid}.json"))
        except (OSError, ValueError):
            return None
        sid, cwd = s.get("sessionId"), s.get("cwd") or ""
        p = f"{home}/.claude/projects/{re.sub(r'[^A-Za-z0-9]', '-', cwd)}/{sid}.jsonl"
        found = [p] if os.path.exists(p) else glob.glob(f"{home}/.claude/projects/*/{sid}.jsonl")
    elif app == "pi" and pi_session:
        found = glob.glob(f"{home}/.pi/agent/sessions/*/*_{pi_session}.jsonl")
    else:
        return None
    return found[0] if found else None


def text_of(content):
    if isinstance(content, str):
        return content
    return "\n".join(b.get("text", "") for b in content or [] if isinstance(b, dict) and b.get("type") == "text")


path = transcript()
if not path:
    print(json.dumps({"error": "no transcript"}))
    sys.exit()
key = f"{path}:{os.path.getsize(path)}"
if key == last:
    print('{"same": true}')
    sys.exit()

prompts, context = [], 0
for line in open(path, errors="replace"):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if app == "pi":
        if e.get("type") != "message":
            continue
        m = e.get("message") or {}
        u = m.get("usage") or {}
        out, used = u.get("output", 0), u.get("input", 0) + u.get("cacheRead", 0) + u.get("cacheWrite", 0)
        tool = "toolCall"
    else:
        if e.get("type") not in ("user", "assistant") or e.get("isMeta") or e.get("isSidechain") or e.get("isCompactSummary"):
            continue
        m = e.get("message") or {}
        u = m.get("usage") or {}
        out = u.get("output_tokens", 0)
        used = u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0) + u.get("cache_creation_input_tokens", 0)
        tool = "tool_use"
    role, content, at = m.get("role"), m.get("content"), e.get("timestamp")
    blocks = content if isinstance(content, list) else []
    if role == "user":
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in blocks):
            continue
        s = text_of(content).strip()
        # Command output, reminders and notifications start with a tag; a peer's hc message is a prompt.
        if not s or (s.startswith("<") and not s.startswith("<hc ")) or s.startswith("[Request interrupted"):
            continue
        prompts.append({"at": at, "done": at, "text": s[:4000], "tokens": {}, "tools": 0, "reply": ""})
    elif role == "assistant" and prompts:
        p = prompts[-1]
        p["done"] = at
        # Claude Code repeats a message's usage on each of its blocks: count each message once.
        mid = m.get("id") or e.get("id")
        p["tokens"][mid] = max(p["tokens"].get(mid, 0), out)
        p["tools"] += sum(1 for b in blocks if isinstance(b, dict) and b.get("type") == tool)
        reply = text_of(content).strip()
        if reply:
            p["reply"] = reply[:2000]
        if used:
            context = used

for n, p in enumerate(prompts, 1):
    p["n"], p["tokens"] = n, sum(p["tokens"].values())
print(json.dumps({"key": key, "context": context, "total": len(prompts), "prompts": prompts[-40:]}))
