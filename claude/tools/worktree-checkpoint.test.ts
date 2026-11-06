import { afterEach, beforeEach, expect, test } from "bun:test";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CARD = "# probe\n\n## Goal\nDiscussion only; no implementation approved.\n\n## Done when\nOwner chooses scope.\n\n## State\nWaiting on owner.\n\n## Neighbours\nNone.\n";
let cwd: string;
let card: string;

const age = (path: string, seconds: number) => utimesSync(path, Date.now() / 1000 + seconds, Date.now() / 1000 + seconds);

beforeEach(() => {
  cwd = mkdtempSync(join(tmpdir(), "claude-checkpoint-test-"));
  execFileSync("git", ["init", "-q", "--initial-branch=wt/probe", cwd]);
  execFileSync("git", ["-C", cwd, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-q", "--allow-empty", "-m", "test: seed"]);
  writeFileSync(join(cwd, "CLAUDE.md"), "Read ~/nerdtools/claude/playbooks/worktree.md.\n");
  card = join(cwd, ".cards/probe.md");
  mkdirSync(join(cwd, ".cards"));
  writeFileSync(card, CARD);
  age(card, 10);
});

afterEach(() => rmSync(cwd, { recursive: true, force: true }));

function runHook(event: object) {
  const env = { ...process.env, CLAUDE_CODE_AUTO_COMPACT_WINDOW: "533000", TMPDIR: cwd };
  const result = spawnSync("bun", [join(import.meta.dir, "worktree-checkpoint.ts")], { input: JSON.stringify({ cwd, ...event }), cwd, env, encoding: "utf8" });
  return { code: result.status, stdout: result.stdout, stderr: result.stderr };
}

function context(tokens: number) {
  const transcript = join(cwd, "transcript.jsonl");
  const usage = { input_tokens: 2, cache_creation_input_tokens: 1000, cache_read_input_tokens: tokens - 1102, output_tokens: 100 };
  writeFileSync(transcript, JSON.stringify({ type: "assistant", message: { usage } }) + "\n");
  return { transcript_path: transcript, session_id: "probe" };
}

function editCode() {
  const code = join(cwd, "code.txt");
  writeFileSync(code, "changed");
  age(code, 20);
}

test("manual compact passes when State is newer than changes", () => {
  const result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code, result.stderr).toBe(0);
});

test("manual compact blocks on stale State and names the change", () => {
  editCode();
  let result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code).toBe(2);
  expect(result.stderr).toContain("predates code.txt");
  age(card, 30);
  result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code, result.stderr).toBe(0);
});

test("auto compact proceeds and SessionStart asks for State", () => {
  editCode();
  let result = runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(783_000) });
  expect(result.code, result.stderr).toBe(0);
  result = runHook({ hook_event_name: "SessionStart", source: "compact" });
  expect(result.code, result.stderr).toBe(0);
  expect(result.stdout).toContain("overwrite that State from the summary");
  expect(runHook({ hook_event_name: "SessionStart", source: "startup" }).stdout).toBe("");
});

test("card edit alone is not a change", () => {
  writeFileSync(card, CARD + "More.\n");
  age(card, 40);
  const result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code, result.stderr).toBe(0);
});

test("over-budget card blocks manual compact", () => {
  writeFileSync(card, CARD + "x".repeat(8000));
  const result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code).toBe(2);
  expect(result.stderr).toContain("owner must shorten it");
});

test("non-applicable repository passes", () => {
  unlinkSync(join(cwd, "CLAUDE.md"));
  editCode();
  const result = runHook({ hook_event_name: "PreCompact", trigger: "manual" });
  expect(result.code, result.stderr).toBe(0);
});

test("context near compaction asks once per event for relaunch", () => {
  age(card, -60);
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(399_000) }).stdout).toBe("");
  const result = runHook({ hook_event_name: "PostToolBatch", ...context(400_000) });
  expect(result.code, result.stderr).toBe(0);
  const reminder = JSON.parse(result.stdout).hookSpecificOutput.additionalContext;
  expect(reminder).toContain("400k tokens");
  expect(reminder).toContain("near 500k");
  expect(reminder).toContain("/worktree-relaunch");
  expect(reminder).toContain("/clear this session; do not compact");
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(410_000) }).stdout).toBe("");
  expect(runHook({ hook_event_name: "Stop", stop_hook_active: true, ...context(410_000) }).stdout).toBe("");
  const stop = JSON.parse(runHook({ hook_event_name: "Stop", ...context(410_000) }).stdout);
  expect(stop.hookSpecificOutput.additionalContext).toContain("/worktree-relaunch");
  expect(runHook({ hook_event_name: "Stop", ...context(420_000) }).stdout).toBe("");
  runHook({ hook_event_name: "PostToolBatch", ...context(50_000) });
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(401_000) }).stdout).toContain("additionalContext");
  age(card, 3600);
  expect(runHook({ hook_event_name: "Stop", ...context(402_000) }).stdout).toBe("");
});

test("context reminder skips sessions without a card", () => {
  unlinkSync(join(cwd, "CLAUDE.md"));
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(490_000) }).stdout).toBe("");
});

test("auto compaction waits for the relaunch, up to the defer limit", () => {
  age(card, -60);
  const deferred = runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(478_000) });
  expect(deferred.code).toBe(2);
  expect(deferred.stderr).toContain("/worktree-relaunch");
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(683_000) }).code).toBe(0);
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(478_000) }).stdout).toContain("/worktree-relaunch");
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(479_000) }).code).toBe(2);
  age(card, 3600);
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(480_000) }).code).toBe(0);
  unlinkSync(join(cwd, "CLAUDE.md"));
  rmSync(join(cwd, "claude-relaunch-probe"), { force: true });
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(478_000) }).code).toBe(0);
});

test("a card that fails its check still gets the relaunch reminder", () => {
  writeFileSync(card, CARD + "x".repeat(8000));
  age(card, -60);
  const reminder = JSON.parse(runHook({ hook_event_name: "PostToolBatch", ...context(410_000) }).stdout).hookSpecificOutput.additionalContext;
  expect(reminder).toContain("/worktree-relaunch");
  expect(reminder).toContain("owner must shorten it");
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(478_000) }).code).toBe(2);
});

test("running background work turns the Stop reminder into a wait, then the relaunch", () => {
  age(card, -60);
  const tasks = [{ id: "a1", type: "subagent", agent_type: "general-purpose", status: "running", description: "trace lowering" }];
  const waiting = JSON.parse(runHook({ hook_event_name: "Stop", background_tasks: tasks, ...context(410_000) }).stdout).hookSpecificOutput.additionalContext;
  expect(waiting).toContain("subagent general-purpose \"trace lowering\"");
  expect(waiting).toContain("do not stop these");
  expect(runHook({ hook_event_name: "Stop", background_tasks: tasks, ...context(412_000) }).stdout).toBe("");
  const relaunch = JSON.parse(runHook({ hook_event_name: "Stop", background_tasks: [], ...context(415_000) }).stdout).hookSpecificOutput.additionalContext;
  expect(relaunch).toContain("/clear this session");
});

test("a session that keeps working after its relaunch is not reminded again", () => {
  age(card, -60);
  expect(runHook({ hook_event_name: "PostToolBatch", ...context(400_000) }).stdout).toContain("/worktree-relaunch");
  age(card, 5);
  expect(runHook({ hook_event_name: "Stop", ...context(420_000) }).stdout).toBe("");
  expect(runHook({ hook_event_name: "Stop", background_tasks: [{ type: "subagent", description: "x" }], ...context(435_000) }).stdout).toBe("");
  expect(runHook({ hook_event_name: "PreCompact", trigger: "auto", ...context(470_000) }).code).toBe(0);
});
