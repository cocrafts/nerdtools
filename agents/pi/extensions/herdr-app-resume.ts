// Records this Pi session on its herdr-core terminal, so the Herdr app's agent-resume mod
// (conf/herdr-app/mods/agent-resume) can type `pi <flags> --session <id>` into the new shell
// after a reboot. The labels match the mod's Claude Code hook (hooks/herdr-agent-resume.sh).
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const VALUE_FLAGS = new Set([
  "--provider", "--model", "--api-key", "--system-prompt", "--append-system-prompt", "--mode",
  "--session", "--session-id", "--fork", "--session-dir", "--name", "-n", "--models", "--tools", "-t",
  "--exclude-tools", "-xt", "--thinking", "--extension", "-e", "--skill", "--prompt-template",
  "--theme", "--use-theme", "--export", "--tui-mode",
]);
const SESSION_FLAGS = new Set(["--session", "--session-id", "--fork", "--resume", "-r", "--continue", "-c"]);
// A secret or free text never goes into a label that is later typed into a shell.
const NEVER_KEPT = new Set(["--api-key", "--system-prompt", "--append-system-prompt", "--name", "-n"]);
const ONE_SHOT = new Set(["--print", "-p", "--no-session", "--mode", "--export"]);
const SAFE = /^[\w.:/=-]+$/;

// The flags to start this session again, or null for a run that is not an interactive session.
export function resumeFlags(argv: string[]): string | null {
  const keep: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    const name = tok.split("=")[0];
    if (!tok.startsWith("-")) continue;
    if (ONE_SHOT.has(name)) return null;
    const value = VALUE_FLAGS.has(name) && !tok.includes("=") ? argv[++i] : undefined;
    if (SESSION_FLAGS.has(name) || NEVER_KEPT.has(name)) continue;
    const pair = value === undefined ? [tok] : [tok, value];
    if (pair.every((t) => SAFE.test(t))) keep.push(...pair);
  }
  return keep.join(" ");
}

const hc = (args: string[]): Promise<string> =>
  new Promise((resolve) => execFile("hc", args, { timeout: 5000 }, (err, stdout) => resolve(err ? "" : stdout)));

export default function (pi: ExtensionAPI) {
  const terminal = process.env.HC_TERMINAL_ID;
  if (!terminal) return;
  const flags = resumeFlags(process.argv.slice(2));
  if (flags === null) return;
  let recorded: string | undefined;
  // Pi writes the session file after the first message; `--session <id>` finds nothing before.
  const record = async (ctx: ExtensionContext) => {
    const session = ctx.sessionManager.getSessionId();
    const file = ctx.sessionManager.getSessionFile();
    if (!session || session === recorded || !SAFE.test(session) || !file || !existsSync(file)) return;
    let shellPid: unknown;
    try {
      shellPid = JSON.parse(await hc(["get", terminal, "--json"])).pid;
    } catch {
      return;
    }
    if (!Number.isInteger(shellPid)) return;
    await hc(["label", terminal, "resume.agent=pi", `resume.session=${session}`, `resume.pid=${shellPid}`, `resume.args=${flags}`, "resume.tried="]);
    recorded = session;
  };
  pi.on("session_start", (_event, ctx) => record(ctx));
  pi.on("agent_end", (_event, ctx) => record(ctx));
}
