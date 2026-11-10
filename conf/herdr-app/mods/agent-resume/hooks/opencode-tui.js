// OpenCode TUI plugin for the Herdr app mod "agent-resume".
//
// It runs in the OpenCode TUI process, so it sees the terminal environment
// (HC_TERMINAL_ID). Every second it reads the session that the TUI shows (its
// root session, not a child) and writes it on the herdr-core terminal:
//   resume.agent=opencode, resume.session=<id>, resume.pid=<shell pid>, resume.args=<flags>
// After a reboot the mod sees a new shell pid and types
// "opencode <flags> --session <id>".
//
// Install: copy this file to ~/.config/opencode/ and add it to
// ~/.config/opencode/tui.jsonc: { "plugin": ["./herdr-agent-resume-opencode.js"] }

import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const POLL_MS = 1000;
// Session flags that the mod adds again, and flags with a separate value.
const DROP = new Set(["--continue", "-c", "--session", "-s", "--prompt"]);
const DROP_WITH_VALUE = new Set(["--session", "-s", "--prompt"]);
const VALUES = new Set(["--server", "--log-level", "-m", "--model", "--agent"]);
const SAFE = /^[\w.:/\\=-]+$/;

// The hc program of herdr-core: "hc" from the PATH. On Windows, when it is not on the
// PATH, the hc.exe of the installer folder (%LOCALAPPDATA%\Programs\herdr-core), which
// the installer does not add to the PATH.
const INSTALLED_HC = process.platform === "win32" && process.env.LOCALAPPDATA
  ? join(process.env.LOCALAPPDATA, "Programs", "herdr-core", "hc.exe")
  : null;
let hc = "hc";

function run(args) {
  return new Promise((resolve) => {
    execFile(hc, args, { windowsHide: true, timeout: 5000 }, (error, stdout) => {
      if (error?.code === "ENOENT" && hc === "hc" && INSTALLED_HC && existsSync(INSTALLED_HC)) {
        hc = INSTALLED_HC;
        resolve(run(args));
        return;
      }
      resolve(error ? null : String(stdout));
    });
  });
}

// The flags of this opencode command, without session flags and the folder argument.
function resumeArgs() {
  const argv = process.argv.slice(1).filter((a) => !/opencode(\.exe|\.js)?$/i.test(a) && !/[\\/]opencode[\\/]/i.test(a));
  const keep = [];
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    const name = tok.split("=")[0];
    if (DROP.has(name)) {
      if (DROP_WITH_VALUE.has(tok) && i + 1 < argv.length) i++;
      continue;
    }
    if (VALUES.has(tok) && i + 1 < argv.length) {
      if (SAFE.test(argv[i + 1])) keep.push(tok, argv[i + 1]);
      i++;
      continue;
    }
    if (/^--?[A-Za-z][\w-]*(=[\w.:/\\-]+)?$/.test(tok)) keep.push(tok);
  }
  return keep.join(" ");
}

function start(currentRoot) {
  const terminal = process.env.HC_TERMINAL_ID;
  if (!terminal) return () => {};
  const args = resumeArgs();
  let recorded;
  let busy = false;

  const poll = setInterval(async () => {
    if (busy) return;
    let id;
    try {
      id = currentRoot();
    } catch {
      return;
    }
    if (typeof id !== "string" || !/^[\w-]+$/.test(id) || id === recorded) return;
    busy = true;
    try {
      const out = await run(["get", terminal, "--json"]);
      const pid = out ? JSON.parse(out).pid : undefined;
      if (pid === undefined) return;
      const ok = await run(["label", terminal, "resume.agent=opencode", `resume.session=${id}`,
        `resume.pid=${pid}`, `resume.args=${args}`, "resume.tried="]);
      if (ok !== null) recorded = id;
    } catch {
      // Try again on the next poll.
    } finally {
      busy = false;
    }
  }, POLL_MS);
  poll.unref?.();
  return () => clearInterval(poll);
}

// The root of a session: a child session (a sub-agent) belongs to its parent.
function rootOf(id, get) {
  const seen = new Set();
  while (typeof id === "string" && !seen.has(id)) {
    seen.add(id);
    const session = get(id);
    if (!session) return id;
    if (!session.parentID) return id;
    id = session.parentID;
  }
}

// OpenCode V1 TUI plugin API.
async function tui(api) {
  const stop = start(() => {
    const route = api.route.current;
    const id = route?.name === "session" ? route.params?.sessionID : undefined;
    return rootOf(id, (s) => api.state.session.get(s));
  });
  api.lifecycle?.onDispose?.(stop);
}

// OpenCode V2 TUI plugin API.
function setup(api) {
  return start(() => {
    const route = api.ui.router.current();
    const id = route?.type === "session" ? route.sessionID : undefined;
    return rootOf(id, (s) => api.data.session.get(s));
  });
}

export default { id: "herdr.agent-resume", setup, tui };
