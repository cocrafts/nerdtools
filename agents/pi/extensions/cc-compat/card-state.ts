import { spawnSync } from "node:child_process";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const HOME = process.env.HOME ?? process.env.USERPROFILE ?? "";
const TOOL = join(HOME, "nerdtools", "claude", "tools", "wt.sh");
const CONTRACT = join(HOME, "nerdtools", "claude", "tools", "card-state.py");

interface Snapshot {
  cwd: string;
  path: string;
  text: string;
  hash: string;
  head: string;
  tree: string;
  status: string;
  tracked_diff: string;
}

function run(command: string, args: string[], cwd: string, input?: unknown): unknown {
  const result = spawnSync(command, args, {
    cwd,
    env: { ...process.env, WT_CWD: cwd },
    input: input === undefined ? undefined : JSON.stringify(input),
    encoding: "utf8",
    timeout: 15_000,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    throw new Error(result.error?.message ?? (result.stderr.trim() || `${command} exited ${result.status}`));
  }
  return JSON.parse(result.stdout);
}

function snapshot(cwd: string): Snapshot | null {
  return run("bash", [TOOL, "snapshot"], cwd) as Snapshot | null;
}

function contract(command: string, cwd: string, input: unknown): any {
  return run("python3", [CONTRACT, command], cwd, input);
}

export function withoutCardSnapshots(messages: any[]): any[] {
  return messages.flatMap(message => {
    if (message.role !== "custom") return [message];
    if (message.details?.cardSnapshot === true || message.customType === "worktree-card-error") return [];
    if (message.customType !== "claude-context" || typeof message.content !== "string") return [message];
    const marker = message.content.indexOf("Worktree/card state:\n");
    if (marker < 0) return [message];
    const prefix = message.content.slice(0, marker).trim();
    const legacy = message.content.slice(marker + "Worktree/card state:\n".length).trim();
    const card = legacy.search(/^Card of this worktree, .+:\n/m);
    const inbox = [...legacy.matchAll(/^\d+ (?:note\(s\)|card\(s\)) in \/[^\n]+/gm)].at(-1);
    const extras = card < 0 ? legacy : [legacy.slice(0, card), inbox && inbox.index > card ? legacy.slice(inbox.index) : ""].map(part => part.trim()).filter(Boolean).join("\n\n");
    const content = [prefix, extras && `Worktree context (card projected separately):\n\n${extras}`].filter(Boolean).join("\n\n");
    return content ? [{ ...message, content }] : [];
  });
}

export function registerCardState(pi: ExtensionAPI): (details: any) => string | undefined {
  const previews = new Map<string, string>();
  const refresh = (cwd: string): { data: Snapshot; content: string } | null => {
    const data = snapshot(cwd);
    if (!data) return null;
    const content = contract("render", cwd, data) as string;
    previews.set(data.path, content);
    return { data, content };
  };
  const report = (error: unknown, ctx: any): string => {
    const message = `Worktree checkpoint failed: ${error instanceof Error ? error.message : String(error)}`;
    try {
      ctx.ui.notify(message, "error");
    } catch {
      console.error(message);
    }
    return message;
  };

  const staleness = (cwd: string): string | null => {
    const data = snapshot(cwd);
    return data ? contract("stale", cwd, data) : null;
  };

  pi.on("session_before_compact", async (event, ctx) => {
    if (event.reason !== "manual") return;
    try {
      const reason = staleness(ctx.cwd);
      if (!reason) return;
      report(new Error(`${reason}. Ask this session to update its card, then /compact again.`), ctx);
    } catch (error) {
      report(error, ctx);
    }
    return { cancel: true };
  });

  pi.on("session_compact", (_event, ctx) => {
    try {
      const reason = staleness(ctx.cwd);
      if (!reason) return;
      pi.sendMessage({
        customType: "worktree-card-stale",
        content: `Compaction ran before the card was checkpointed: ${reason}. Before other work, overwrite that State from the summary, labelling transcript-reported results as unverified.`,
        display: true,
      }, { triggerTurn: false });
    } catch (error) {
      report(error, ctx);
    }
  });

  pi.on("context", (event, ctx) => {
    const messages = withoutCardSnapshots(event.messages);
    try {
      const current = refresh(ctx.cwd);
      if (!current) return { messages };
      return { messages: [...messages, {
        role: "custom" as const,
        customType: "claude-context",
        content: current.content,
        display: false,
        details: { cardSnapshot: true, path: current.data.path },
        timestamp: Date.now(),
      }] };
    } catch (error) {
      const content = report(error, ctx) + ". Do not act on stale card/summary state. The owner must fix the named card error before code work.";
      return { messages: [...messages, { role: "custom" as const, customType: "worktree-card-error", content, display: false, timestamp: Date.now() }] };
    }
  });

  pi.on("session_start", (event, ctx) => {
    try {
      const current = refresh(ctx.cwd);
      if (!current || event.reason === "reload") return;
      if (ctx.sessionManager.getBranch().some(entry => entry.type === "custom_message" && (entry.details as any)?.cardSnapshot === true && (entry.details as any).path === current.data.path)) return;
      pi.sendMessage({
        customType: "claude-context",
        content: `Card of this worktree, ${current.data.path}:\nCurrent card is projected from disk, not stored in this message.`,
        display: true,
        details: { cardSnapshot: true, path: current.data.path },
      }, { triggerTurn: false });
    } catch (error) {
      report(error, ctx);
    }
  });

  return details => details?.cardSnapshot === true ? previews.get(details.path) : undefined;
}
