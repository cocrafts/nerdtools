// installed by Rexa; reinstalling overwrites this file.
// REXA_INTEGRATION_ID=pi
// REXA_INTEGRATION_VERSION=1

import { spawn } from "node:child_process";

const SLUG = "pi";
const terminalId = process.env.REXA_TERMINAL_ID;

function post(payload: Record<string, unknown>): void {
  if (!terminalId) return;
  try {
    // `rexa` is a `.cmd` shim on Windows, which only a shell resolves.
    const child = spawn("rexa", ["post", SLUG], {
      stdio: ["pipe", "ignore", "ignore"],
      shell: process.platform === "win32",
      windowsHide: true,
    });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(payload));
    child.unref();
  } catch {
    // A hook never fails its caller's turn.
  }
}

/**
 * Both calls stay on `sessionManager`: detaching the method drops its
 * receiver, and the value comes back empty for a manager that keeps its
 * session on itself.
 */
function sessionOf(ctx: any): { sessionId?: string; sessionPath?: string } {
  let sessionId: string | undefined;
  let sessionPath: string | undefined;
  try {
    const id = ctx?.sessionManager?.getSessionId?.();
    if (typeof id === "string" && id) sessionId = id;
  } catch {
    // A manager with no session yet answers nothing, not an error.
  }
  try {
    const file = ctx?.sessionManager?.getSessionFile?.();
    if (typeof file === "string" && file) sessionPath = file;
  } catch {
    // The file appears with the session's first record, not before.
  }
  return { sessionId, sessionPath };
}

export default function (pi: any) {
  // Only the session that owns the UI owns the terminal.
  const report = (event: string, ctx: any, extra: Record<string, unknown> = {}) => {
    if (ctx?.hasUI !== true) return;
    post({ event, ...sessionOf(ctx), ...extra });
  };

  pi.on("session_start", (_event: unknown, ctx: any) => report("session_start", ctx));
  pi.on(
    "session_switch",
    (event: any, ctx: any) => report("session_switch", ctx, { reason: event?.reason }),
  );
  pi.on("agent_start", (_event: unknown, ctx: any) => report("agent_start", ctx));
  pi.on(
    "agent_end",
    (event: any, ctx: any) => report("agent_end", ctx, { willContinue: event?.willContinue }),
  );
}
