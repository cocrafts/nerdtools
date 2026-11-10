// Shared logic of agent-resume: the agents, the config, the labels and the resume command.
// The status bar copy (the scanner) and the panel copy both use this module.
//
// Labels on a herdr-core terminal (written by a hook, a plugin or this mod):
//   resume.agent   = an id of AGENTS (claude, codex, agy, opencode)
//   resume.session = the session id (empty in the mode without a hook)
//   resume.pid     = the pid of the shell that ran the agent
//   resume.args    = the flags of the agent command
//   resume.tried   = the shell pid of the last resume attempt

import { terminals, hc, shared, setShared } from "herdr";

// One entry for each agent. app: the program name that the agent reports (status.app).
// resume: the command with a session id. last: the command without one (the last
// session in the folder). {args} is the recorded flags, {id} the session id.
export const AGENTS = {
  claude: { name: "Claude Code", app: "claude-code", resume: "claude {args} --resume {id}", last: "claude {args} --continue" },
  codex: { name: "Codex", app: "codex", resume: "codex resume {args} {id}", last: "codex resume {args} --last" },
  agy: { name: "Antigravity", app: "antigravity", resume: "agy {args} --conversation {id}", last: "agy {args} --continue" },
  opencode: { name: "OpenCode", app: "opencode", resume: "opencode {args} --session {id}", last: "opencode {args} --continue" },
  pi: { name: "Pi", app: "pi", resume: "pi {args} --session {id}", last: "pi {args} --continue" },
};

export const LABELS = ["resume.agent", "resume.session", "resume.pid", "resume.args", "resume.tried"];

export function agentForApp(app) {
  return Object.keys(AGENTS).find((id) => AGENTS[id].app === app) ?? null;
}

export const CONFIG_KEY = "agent-resume.config";
// enabled: auto resume. settleMs: the shell wait. toast: a notification after a resume.
// noHook: record agents that have no hook, and resume their last session in the folder.
const DEFAULTS = { enabled: true, settleMs: 4000, toast: true, noHook: false };
export const SETTLE_MIN_MS = 1000;
export const SETTLE_MAX_MS = 30000;

export const SHELLS = new Set([
  "pwsh", "pwsh.exe", "powershell", "powershell.exe", "cmd", "cmd.exe",
  "bash", "bash.exe", "zsh", "fish", "sh", "dash", "nu", "nu.exe",
]);

export function config() {
  const c = shared(CONFIG_KEY);
  return { ...DEFAULTS, ...(c && typeof c === "object" ? c : {}) };
}

export function setConfig(patch) {
  setShared(CONFIG_KEY, { ...config(), ...patch });
}

// Live terminals that have a recorded agent.
export function labeled() {
  return terminals().filter((t) => t.state === "live" && AGENTS[t.labels?.["resume.agent"]]);
}

// The full terminal record (with pid and foreground), or null.
export async function inspect(address) {
  const r = await hc(["get", address, "--json"]);
  if (r.code !== 0) return null;
  try {
    return JSON.parse(r.stdout);
  } catch {
    return null;
  }
}

// The state of one recorded terminal:
//   active  - an agent runs in the terminal now
//   failed  - the mod typed the resume command in this shell, and no agent started
//   waiting - the shell is new (other pid): the next scan resumes it
//   stopped - the agent ended in the same shell
export function sessionState(info) {
  const l = info?.labels ?? {};
  if (info?.status) return "active";
  if (info && l["resume.tried"] && l["resume.tried"] === String(info.pid)) return "failed";
  if (info && String(info.pid) !== l["resume.pid"]) return "waiting";
  return "stopped";
}

// The command to type, or null if a label has unsafe characters.
export function resumeCommand(labels) {
  const agent = AGENTS[labels?.["resume.agent"]];
  if (!agent) return null;
  const id = labels["resume.session"] ?? "";
  if (id && !/^[A-Za-z0-9_-]+$/.test(id)) return null;
  const args = (labels["resume.args"] ?? "").trim();
  if (!/^[\w.:/\\= -]*$/.test(args)) return null;
  const template = id ? agent.resume : agent.last;
  return template.replace("{args}", args).replace("{id}", id).replace(/\s+/g, " ").trim();
}

// Types the resume command in the terminal. It never types into a running agent
// or into a program that is not a shell. Returns true when it typed.
export async function resumeNow(address) {
  const info = await inspect(address);
  if (!info || info.state !== "live" || info.status) return false;
  const fg = (info.foreground?.name ?? "").toLowerCase();
  if (!SHELLS.has(fg)) return false;
  const command = resumeCommand(info.labels);
  if (!command) return false;
  // The mark is the shell pid: a failed resume is not tried again in the same shell.
  const mark = await hc(["label", address, `resume.tried=${info.pid}`]);
  if (mark.code !== 0) return false;
  const sent = await hc(["send", address, command]);
  return sent.code === 0;
}

// Removes the labels: the mod stops to monitor this terminal.
export async function forget(address) {
  const r = await hc(["label", address, ...LABELS.map((k) => `${k}=`)]);
  return r.code === 0;
}

// An agent runs in this terminal now. If the shell is new (a resume, or an agent started
// by hand after a reboot), write the new shell pid, so the next reboot is seen.
export async function refreshPid(address) {
  const info = await inspect(address);
  if (!info || !info.status) return false;
  if (String(info.pid) === info.labels?.["resume.pid"]) return true;
  const r = await hc(["label", address, `resume.pid=${info.pid}`, "resume.tried="]);
  return r.code === 0;
}

// Records an agent that has no hook: no session id, so the resume uses the "last" command.
export async function recordWithoutHook(address, agentId) {
  const info = await inspect(address);
  if (!info || !info.status || info.labels?.["resume.agent"]) return false;
  const r = await hc(["label", address, `resume.agent=${agentId}`, "resume.session=", `resume.pid=${info.pid}`, "resume.args=", "resume.tried="]);
  return r.code === 0;
}
