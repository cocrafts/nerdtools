import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, utimesSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to installed Pi");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
  "@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
  "@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
} });
const { default: compat } = await loader.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/cc-compat.ts"));
const { withoutCardSnapshots } = await loader.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/cc-compat/card-state.ts"));
assert.deepEqual(withoutCardSnapshots([
  { role: "custom", customType: "claude-context", content: "Coach board facts\n\nWorktree/card state:\n\nHandoff from the previous session, /tmp/handoff.md:\nHOT_STEP\n\nCard of this worktree, /tmp/card.md:\nOLD_CARD\n3 card(s) in /tmp/.inbox/compiler: 3 open\npins: KEEP_PIN" },
  { role: "custom", customType: "claude-context", content: "new pointer", details: { cardSnapshot: true } },
  { role: "custom", customType: "other-context", content: "Keep unrelated context" },
]), [
  { role: "custom", customType: "claude-context", content: "Coach board facts\n\nWorktree context (card projected separately):\n\nHandoff from the previous session, /tmp/handoff.md:\nHOT_STEP\n\n3 card(s) in /tmp/.inbox/compiler: 3 open\npins: KEEP_PIN" },
  { role: "custom", customType: "other-context", content: "Keep unrelated context" },
]);
assert.deepEqual(withoutCardSnapshots([{ role: "custom", customType: "claude-context", content: "Worktree/card state:\n\n2 note(s) in /tmp/.inbox/repo — read them before other work" }]), [{ role: "custom", customType: "claude-context", content: "Worktree context (card projected separately):\n\n2 note(s) in /tmp/.inbox/repo — read them before other work" }]);
const pi = await import(pathToFileURL(join(root, "dist/index.js")));
const ai = await import(pathToFileURL(join(root, "node_modules/@earendil-works/pi-ai/dist/index.js")));
const temp = mkdtempSync(join(tmpdir(), "pi-card-checkpoint-"));
const agentDir = join(temp, "agent");
mkdirSync(agentDir);
const git = (...args) => execFileSync("git", ["-C", temp, ...args], { encoding: "utf8" });
git("init", "-q", "--initial-branch=wt/probe");
git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-q", "--allow-empty", "-m", "test: seed");
writeFileSync(join(temp, "CLAUDE.md"), "Read ~/nerdtools/claude/playbooks/worktree.md before card work.\n");
mkdirSync(join(temp, ".cards"));
const cardPath = join(temp, ".cards/probe.md");
const card = "# probe\n\n## Goal\nDo not implement; preserve scope.\n\n## Done when\nOwner chooses next scope.\n\n## State\nVISIBLE_INITIAL_STATE\n\n## Neighbours\nNone.\n";
writeFileSync(cardPath, card);
const touch = (path, offset) => { const at = Date.now() / 1000 + offset; utimesSync(path, at, at); };
touch(cardPath, 10);
let session;
const seen = [], notices = [];
let summaries = 0;
const faux = ai.fauxProvider({ provider: "card-proof", models: [{ id: "fixture", contextWindow: 100000, maxTokens: 8192 }] });
const respond = async context => {
  if (context.messages.some(m => m.role === "system" && typeof m.content === "string" && m.content.includes("summariz"))) {
    summaries++;
    return ai.fauxAssistantMessage("SUMMARY");
  }
  seen.push(structuredClone(context));
  return ai.fauxAssistantMessage("Probe observation; implementation still needs owner approval.");
};
const queue = () => faux.setResponses(Array.from({ length: 24 }, () => respond));
const settings = pi.SettingsManager.inMemory({ compaction: { enabled: false, reserveTokens: 70000, keepRecentTokens: 0 }, retry: { enabled: false } });
try {
  const resources = new pi.DefaultResourceLoader({ cwd: temp, agentDir, settingsManager: settings, noExtensions: true, noContextFiles: true, noSkills: true, noPromptTemplates: true, noThemes: true, extensionFactories: [api => {
    api.registerProvider(faux.provider);
    compat(api);
  }] });
  await resources.reload();
  ({ session } = await pi.createAgentSession({ cwd: temp, agentDir, settingsManager: settings, resourceLoader: resources, sessionManager: pi.SessionManager.inMemory(temp), model: faux.getModel(), noTools: true }));
  await session.bindExtensions({ mode: "json", uiContext: { notify: text => { notices.push(text); } } });
  queue();
  await session.prompt("Inspect current card, no implementation.");
  assert.ok(JSON.stringify(seen.at(-1)).includes("VISIBLE_INITIAL_STATE"));
  assert.ok(!JSON.stringify(session.sessionManager.getBranch()).includes("VISIBLE_INITIAL_STATE"));
  await session.compact();
  assert.ok(summaries > 0, "A card newer than every change lets manual compact run as usual");
  let done = summaries;
  console.log("PASS fresh card: manual compact runs with no extra model call");

  const code = join(temp, "code.txt");
  writeFileSync(code, "edit");
  touch(code, 20);
  await session.prompt("Report the edit.");
  await assert.rejects(session.compact(), /Compaction cancelled/);
  assert.equal(summaries, done);
  assert.ok(notices.at(-1).includes("predates code.txt"));
  touch(cardPath, 30);
  await session.compact();
  assert.ok(summaries > done);
  console.log("PASS stale card: manual compact is cancelled until the session updates State");

  writeFileSync(cardPath, card + "x".repeat(8000));
  touch(cardPath, 40);
  await session.prompt("Report the card.");
  await assert.rejects(session.compact(), /Compaction cancelled/);
  assert.ok(notices.at(-1).includes("owner must shorten it"));
  writeFileSync(cardPath, card);
  touch(cardPath, 40);
  console.log("PASS oversized card: manual compact is cancelled with the card error");

  touch(code, 50);
  await session.prompt("Large input for automatic compact\n" + "x".repeat(126000));
  settings.setCompactionEnabled(true);
  const before = summaries;
  await session.prompt("Continue after threshold.");
  assert.ok(summaries > before, "Threshold compaction must proceed on a stale card");
  assert.ok(JSON.stringify(seen.at(-1)).includes("Compaction ran before the card was checkpointed"));
  assert.equal(JSON.stringify(seen.at(-1)).split("Card of this worktree,").length - 1, 1);
  console.log("PASS automatic compact: proceeds, then asks the session to update State");
  console.log("PASS card checkpoint integration");
} finally {
  session?.dispose();
  rmSync(temp, { recursive: true, force: true });
}
