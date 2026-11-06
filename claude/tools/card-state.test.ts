import { afterEach, beforeEach, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, unlinkSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { git, identity, render, snapshot, stale } from "./card-state.ts";

const CARD = "# probe\n\n## Goal\nKeep the approved scope.\n\n## Done when\nA real check passes.\n\n## State\nUnverified; investigation in progress.\n\n## Neighbours\nNone.\n";
let repo: string;
let card: string;

beforeEach(() => {
  repo = mkdtempSync(join(tmpdir(), "card-state-test-"));
  execFileSync("git", ["init", "-q", "--initial-branch=wt/probe", repo]);
  git(repo, "config", "user.name", "Fixture");
  git(repo, "config", "user.email", "fixture@example.invalid");
  git(repo, "commit", "-q", "--allow-empty", "-m", "test: seed");
  card = join(repo, ".cards", "probe.md");
  mkdirSync(join(repo, ".cards"));
  writeFileSync(card, CARD);
  writeFileSync(join(repo, "CLAUDE.md"), "Read ~/nerdtools/claude/playbooks/worktree.md before card work.\n");
});

afterEach(() => rmSync(repo, { recursive: true, force: true }));

const take = () => snapshot(repo, card);
const touch = (path: string, at: number) => utimesSync(path, at, at);

test("unicode character budget, not lines or bytes", () => {
  writeFileSync(card, CARD.replace("Unverified; investigation in progress.", "界".repeat(4000)));
  take();
  writeFileSync(card, CARD.replace("Unverified; investigation in progress.", "界".repeat(4001)));
  expect(take).toThrow("State has 4001 characters");
  writeFileSync(card, CARD.replace("Unverified; investigation in progress.", "😀".repeat(4000)));
  take();
  writeFileSync(card, CARD + "x".repeat(8000));
  expect(take).toThrow("card has");
});

test("rejects missing and duplicate sections", () => {
  for (const text of [CARD.replace("## Goal", "## Other"), CARD + "\n## State\nDuplicate\n"]) {
    writeFileSync(card, text);
    expect(take).toThrow();
  }
});

test("accepts dated headings and repeated log sections", () => {
  writeFileSync(card, CARD.replace("## State", "## State (2026-11-02 10:30Z) — LANDED") + "\n## Log (2026-11-01)\nA\n\n## Log (2026-10-31)\nB\n");
  take();
  writeFileSync(card, CARD + "\n## State (2026-10-01)\nOld\n");
  expect(take).toThrow("duplicate card section: State");
});

test("stale compares card with commit and changed files", () => {
  const future = Date.now() / 1000 + 60;
  touch(card, future);
  expect(stale(take())).toBeNull();
  const code = join(repo, "src", "code.txt");
  mkdirSync(join(repo, "src"));
  writeFileSync(code, "edit");
  touch(code, future + 10);
  expect(stale(take())).toContain("predates src/code.txt");
  git(repo, "add", "src/code.txt");
  git(repo, "mv", "src/code.txt", "src/renamed.txt");
  expect(stale(take())).toContain("predates src/renamed.txt");
  touch(card, future + 20);
  expect(stale(take())).toBeNull();
});

test("untracked contents require consumer reverification", () => {
  const artifact = join(repo, "probe-output.txt");
  writeFileSync(artifact, "first output");
  const data = take();
  writeFileSync(artifact, "changed output");
  expect(identity(repo)).toEqual({ head: data.head, tree: data.tree, status: data.status, tracked_diff: data.tracked_diff });
  expect(render(data)).toContain("do not fingerprint untracked contents or external artifacts");
});

test("snapshot lookup reuses worktree adapter and opt-in", () => {
  const lookup = () => JSON.parse(execFileSync("bash", [join(import.meta.dir, "wt.sh"), "snapshot"], { cwd: repo, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }));
  expect(lookup().path).toBe(realpathSync(card));
  unlinkSync(join(repo, "CLAUDE.md"));
  expect(lookup()).toBeNull();
  writeFileSync(join(repo, "CLAUDE.md"), "~/nerdtools/claude/playbooks/worktree.md\n");
  unlinkSync(card);
  expect(lookup).toThrow();
});

test("symlink card is rejected", () => {
  unlinkSync(card);
  const target = join(repo, "other.md");
  writeFileSync(target, CARD);
  symlinkSync(target, card);
  expect(take).toThrow("symlink");
});
