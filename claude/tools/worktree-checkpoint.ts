import { spawnSync } from "node:child_process";
import { closeSync, existsSync, fstatSync, openSync, readFileSync, readSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { stale, type Snapshot } from "./card-state.ts";

const COMPACT_RESERVE = 33_000;
const RELAUNCH_HEADROOM = 133_000;
const COMPACT_DEFER_LIMIT = 150_000;

function snapshot(cwd: string): Snapshot | null {
  const found = spawnSync("bash", [join(import.meta.dir, "wt.sh"), "snapshot"], { cwd, env: { ...process.env, WT_CWD: cwd }, encoding: "utf8", timeout: 20_000 });
  if (found.error || found.status) throw new Error(found.error?.message ?? (found.stderr.trim() || "worktree snapshot failed"));
  return JSON.parse(found.stdout);
}

function staleness(cwd: string): string | null {
  const data = snapshot(cwd);
  return data && stale(data);
}

function contextTokens(transcript: string): number {
  const handle = openSync(transcript, "r");
  const size = fstatSync(handle).size;
  const tail = Buffer.alloc(Math.min(size, 2_000_000));
  readSync(handle, tail, 0, tail.length, size - tail.length);
  closeSync(handle);
  for (const line of new TextDecoder().decode(tail).split("\n").reverse()) {
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    const usage = entry?.type === "assistant" && !entry.isSidechain ? entry.message?.usage : undefined;
    if (usage) return ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"].reduce((sum, key) => sum + (usage[key] ?? 0), 0);
  }
  return 0;
}

function carded(cwd: string): { path?: string; error?: string } | null {
  try {
    const data = snapshot(cwd);
    return data && { path: data.path };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

interface Mark {
  since: number;
  fired: string[];
}

function readMark(marker: string): Mark | null {
  if (!existsSync(marker)) return null;
  const text = readFileSync(marker, "utf8");
  try {
    return JSON.parse(text);
  } catch {
    return { since: statSync(marker).mtimeMs, fired: text.split(/\s+/).filter(Boolean) };
  }
}

function relaunched(card: { path?: string }, mark: Mark | null): boolean {
  return !!mark && !!card.path && statSync(card.path).mtimeMs > mark.since;
}

function compactWindow(event: any): number {
  return event.agent_id ? 0 : Number(process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW || 0);
}

const markerOf = (event: any) => join(tmpdir(), `claude-relaunch-${event.session_id}`);

function relaunchReminder(event: any, kind: string): string | null {
  const window = compactWindow(event);
  if (!window) return null;
  const tokens = contextTokens(event.transcript_path);
  const marker = markerOf(event);
  if (tokens < window - RELAUNCH_HEADROOM) {
    rmSync(marker, { force: true });
    return null;
  }
  const running: any[] = event.background_tasks ?? [];
  const slot = running.length ? `${kind}-waiting` : kind;
  const mark = readMark(marker);
  const card = mark?.fired.includes(slot) ? null : carded(event.cwd);
  if (!card || relaunched(card, mark)) return null;
  writeFileSync(marker, JSON.stringify({ since: mark?.since ?? Date.now(), fired: [...(mark?.fired ?? []), slot] }));
  const head = `Context is at ${Math.floor(tokens / 1000)}k tokens and this session auto-compacts near ${Math.floor((window - COMPACT_RESERVE) / 1000)}k.`;
  const cardError = card.error ? ` The card check also fails (${card.error}); the relaunch rewrite has to fix it.` : "";
  if (running.length) {
    const tasks = running.map(task => `${task.type ?? "task"} ${task.agent_type ?? task.name ?? ""} "${String(task.description ?? task.command ?? task.id).slice(0, 80)}"`.replace(/\s+/g, " "));
    return `${head} Background work is still running: ${tasks.join("; ")}. Start no new subagents or jobs and do not stop these; wait for each to finish, record its result in the card or handoff, then run the full /worktree-relaunch.${cardError}`;
  }
  return (
    `${head} Reach a chunk boundary now: finish or revert the step in flight and start no new long step. ` +
    "If background subagents or jobs are still running, start no new ones and do not stop them: wait for each to finish and record its result first, because its result returns only to this session. " +
    "Then run the full /worktree-relaunch through the Skill tool (settle, card, handoff, kickstart line, not its compaction variant) " +
    "and end the turn so the person can /clear this session; do not compact." +
    cardError
  );
}

function deferredCompaction(event: any): string | null {
  const window = compactWindow(event);
  if (!window || contextTokens(event.transcript_path) >= window + COMPACT_DEFER_LIMIT) return null;
  const card = carded(event.cwd);
  if (!card || relaunched(card, readMark(markerOf(event)))) return null;
  return "Compaction deferred until this carded session runs /worktree-relaunch and the person clears it; the next tool batch or stop delivers the reminder.";
}

function main() {
  const event = JSON.parse(readFileSync(0, "utf8"));
  const name = event.hook_event_name;
  if (name === "PreCompact") {
    if (event.trigger === "auto") {
      const deferred = deferredCompaction(event);
      if (deferred) {
        console.error(deferred);
        process.exit(2);
      }
      return;
    }
    const reason = staleness(event.cwd);
    if (reason) throw new Error(`${reason}. Ask this session to update its card, then /compact again.`);
  } else if (name === "SessionStart") {
    if (event.source !== "compact") return;
    const reason = staleness(event.cwd);
    if (reason) console.log(`Compaction ran before the card was checkpointed: ${reason}. Before other work, overwrite that State from the summary above, labelling transcript-reported results as unverified.`);
  } else if (name === "PostToolBatch" || name === "Stop") {
    const reminder = event.stop_hook_active ? null : relaunchReminder(event, name);
    if (reminder) console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: name, additionalContext: reminder } }));
  } else {
    throw new Error(`unsupported hook event: ${name}`);
  }
}

try {
  main();
} catch (error) {
  console.error(`Worktree checkpoint: ${(error as Error).message}`);
  process.exit(2);
}
