import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, lstatSync, readFileSync, realpathSync, statSync } from "node:fs";
import { join } from "node:path";

export const STATE_LIMIT = 4000;
export const CARD_LIMIT = 8000;
const REQUIRED = ["Goal", "Done when", "State"];

export interface Snapshot {
  cwd: string;
  path: string;
  text: string;
  hash: string;
  head: string;
  tree: string;
  status: string;
  tracked_diff: string;
}

export function git(cwd: string, ...args: string[]): string {
  return execFileSync("git", ["-C", cwd, ...args], { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 }).trim();
}

export function identity(cwd: string) {
  return {
    head: git(cwd, "rev-parse", "HEAD"),
    tree: git(cwd, "rev-parse", "HEAD^{tree}"),
    status: git(cwd, "status", "--porcelain=v1", "--untracked-files=normal"),
    tracked_diff: createHash("sha256")
      .update(execFileSync("git", ["-C", cwd, "diff", "HEAD", "--no-ext-diff", "--no-textconv", "--binary"], { maxBuffer: 256 * 1024 * 1024 }))
      .digest("hex"),
  };
}

const characters = (text: string) => [...text].length;

export function sections(text: string): Map<string, [number, number]> {
  const spans = new Map<string, [number, number]>();
  const headings = [...text.matchAll(/^## ([^\n]+)\n/gm)];
  headings.forEach((heading, index) => {
    const name = heading[1].split(/\s*[(—]/, 1)[0].trim();
    if (spans.has(name) && REQUIRED.includes(name)) throw new Error(`duplicate card section: ${name}`);
    if (!spans.has(name)) spans.set(name, [heading.index! + heading[0].length, headings[index + 1]?.index ?? text.length]);
  });
  for (const name of REQUIRED) {
    const span = spans.get(name);
    if (!span || !text.slice(...span).trim()) throw new Error(`card requires nonempty ## ${name}`);
  }
  return spans;
}

export function validate(text: string) {
  const spans = sections(text);
  const state = text.slice(...spans.get("State")!).trim();
  if (characters(text) > CARD_LIMIT) throw new Error(`card has ${characters(text)} characters, limit ${CARD_LIMIT}; owner must shorten it`);
  if (characters(state) > STATE_LIMIT) throw new Error(`State has ${characters(state)} characters, limit ${STATE_LIMIT}; owner must shorten it`);
  return spans;
}

export function snapshot(cwd: string, path: string): Snapshot {
  if (lstatSync(path).isSymbolicLink()) throw new Error(`card must not be a symlink: ${path}`);
  const raw = readFileSync(path);
  const text = new TextDecoder("utf-8", { fatal: true }).decode(raw);
  validate(text);
  return {
    cwd: realpathSync(cwd),
    path: realpathSync(path),
    text,
    hash: createHash("sha256").update(raw).digest("hex"),
    ...identity(cwd),
  };
}

export function stale(data: Snapshot): string | null {
  const card = realpathSync(data.path);
  const written = statSync(card).mtimeMs / 1000;
  const changes: [number, string][] = [[Number(git(data.cwd, "log", "-1", "--format=%ct")), "the HEAD commit"]];
  const entries = execFileSync("git", ["-C", data.cwd, "status", "--porcelain=v1", "-z", "--untracked-files=all"], { encoding: "utf8" }).split("\0");
  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    if (!entry) continue;
    if ("RC".includes(entry[0])) index++;
    const path = join(data.cwd, entry.slice(3));
    if (existsSync(path) && realpathSync(path) !== card) changes.push([statSync(path).mtimeMs / 1000, entry.slice(3)]);
  }
  const [changedAt, changed] = changes.reduce((latest, change) => (change[0] > latest[0] || (change[0] === latest[0] && change[1] > latest[1]) ? change : latest));
  if (changedAt <= written) return null;
  return `State of ${card} predates ${changed}; overwrite ## State (Verified, In flight, Blocked, Next) before compaction, because a summary cannot reconstruct evidence that was never checkpointed`;
}

export function render(data: Snapshot): string {
  return (
    `Card of this worktree, ${data.path}:\n` +
    "Current card from disk; not new approval or a test certificate. Reconcile summary conflicts " +
    "against Git/code/named evidence. Verify local claims needed for Next.\n" +
    `Git observed: HEAD ${data.head}; committed tree ${data.tree}; ` +
    `worktree ${data.status ? "dirty" : "clean"}. ` +
    "Git observations do not fingerprint untracked contents or external artifacts; verify them before relying on them.\n\n" +
    data.text
  );
}

function main(args: string[]) {
  const [command, cwd, cardPath] = args;
  if (command === "strip-context" || command === "checked-context") {
    let text = readFileSync(0, "utf8");
    const match = /^Card of this worktree, (.+):\n/m.exec(text);
    if (match) {
      const block = match[0] + readFileSync(match[1], "utf8");
      if (!text.startsWith(block, match.index)) throw new Error("card changed while splitting worktree context");
      const replacement = command === "checked-context" ? render(snapshot(cwd, match[1])) : "";
      text = text.slice(0, match.index) + replacement + text.slice(match.index + block.length);
    } else if (command === "checked-context") {
      throw new Error("worktree context omitted the applicable card");
    }
    process.stdout.write(text);
    return;
  }
  let result: unknown;
  if (command === "snapshot") {
    const lines = cardPath === undefined ? readFileSync(0, "utf8").split(/\r?\n/).filter(Boolean) : [];
    if (cardPath === undefined && !lines.length) throw new Error("worktree card locator returned no path");
    result = snapshot(cwd, cardPath ?? lines[0]);
  } else {
    const data = JSON.parse(readFileSync(0, "utf8"));
    if (command === "stale") result = stale(data);
    else if (command === "render") result = render(data);
    else throw new Error(`unknown card-state command: ${command}`);
  }
  console.log(JSON.stringify(result));
}

if (import.meta.main) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(`card-state: ${(error as Error).message}`);
    process.exit(1);
  }
}
