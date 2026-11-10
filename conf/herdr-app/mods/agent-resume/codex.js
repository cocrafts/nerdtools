// Codex sessions for agent-resume, without a hook.
//
// Codex runs its hooks in a shared background daemon (codex app-server --managed-daemon).
// The daemon has the environment of the terminal that started it, so a hook cannot know
// the terminal of a session. Instead, this module reads the Codex session files:
//   ~/.codex/sessions/YYYY/MM/DD/rollout-YYYY-MM-DDTHH-MM-SS-<id>.jsonl
// The first line (session_meta) has the session id, the cwd and the originator.
// Codex writes the file when the first prompt of a session starts.
//
// A Codex terminal gets the newest interactive session (originator codex-tui) of its
// folder that no other live terminal has.

import * as fs from "fs/promises";
import { home } from "herdr";

const NAME = /^rollout-(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})-([0-9a-f-]{36})\.jsonl$/i;
const DAYS = 2; // today and yesterday
const meta = new Map(); // file path -> { id, cwd, startMs, interactive } (a file never changes its first line)

function pad(n) {
  return String(n).padStart(2, "0");
}

export function sameFolder(a, b) {
  const norm = (p) => String(p ?? "").replace(/[\\/]+$/, "").replace(/\\/g, "/").toLowerCase();
  return !!a && !!b && norm(a) === norm(b);
}

async function readMeta(path) {
  if (meta.has(path)) return meta.get(path);
  let info = null;
  try {
    const text = await fs.readFile(path, "utf8");
    const nl = text.indexOf("\n");
    const first = JSON.parse(nl < 0 ? text : text.slice(0, nl));
    const p = first?.payload ?? {};
    if (first?.type === "session_meta" && p.id) {
      info = {
        id: p.id,
        cwd: p.cwd,
        startMs: Date.parse(p.timestamp) || 0,
        interactive: p.originator === "codex-tui" && (p.thread_source ?? "user") === "user",
      };
    }
  } catch {
    info = null;
  }
  // Cache only a complete record. A file that Codex is still writing is read again later.
  if (info) meta.set(path, info);
  return info;
}

// The interactive Codex sessions of the last DAYS days, newest first.
export async function codexSessions() {
  const root = `${home()}/.codex/sessions`;
  const out = [];
  for (let d = 0; d < DAYS; d++) {
    const day = new Date(Date.now() - d * 86400000);
    const dir = `${root}/${day.getFullYear()}/${pad(day.getMonth() + 1)}/${pad(day.getDate())}`;
    let names;
    try {
      names = await fs.readdir(dir);
    } catch {
      continue;
    }
    for (const name of names) {
      if (!NAME.test(name)) continue;
      const info = await readMeta(`${dir}/${name}`);
      if (info?.interactive) out.push(info);
    }
  }
  return out.sort((a, b) => b.startMs - a.startMs);
}

// Chooses a session for each Codex terminal. terms: [{ address, cwd, session, since }]
//   session: its recorded session id (or "")
//   since: the time the mod saw its agent start (0 if the agent ran before the mod)
// Returns [{ address, id }] for the terminals whose session must change.
export function matchCodex(terms, sessions, takenElsewhere) {
  const taken = new Set(takenElsewhere);
  for (const t of terms) if (t.session) taken.add(t.session);
  const changes = [];
  // Newest agent start first: the newest session belongs to the newest agent.
  const order = [...terms].sort((a, b) => b.since - a.since);
  for (const t of order) {
    const sameCwd = terms.filter((o) => sameFolder(o.cwd, t.cwd));
    const candidates = sessions.filter((s) => sameFolder(s.cwd, t.cwd) && !taken.has(s.id));
    if (candidates.length === 0) continue;
    const newest = candidates[0];
    if (!t.session) {
      // A new agent: only a session that started after the agent (when the mod saw it start).
      if (t.since && newest.startMs < t.since - 5000) continue;
    } else {
      // A new session in the same agent (/new): only if this is the one Codex terminal of the
      // folder, and the session started after the mod saw the agent start.
      if (sameCwd.length !== 1 || !t.since || newest.startMs < t.since) continue;
    }
    taken.add(newest.id);
    changes.push({ address: t.address, id: newest.id });
  }
  return changes;
}
