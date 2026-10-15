import assert from "node:assert/strict";
import { mock } from "node:test";
import { createRequire } from "node:module";
import { mkdtempSync, mkdirSync, symlinkSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
  "typebox/value": join(root, "node_modules/typebox/build/value/index.mjs"),
  "typebox": join(root, "node_modules/typebox/build/index.mjs"),
  "@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
  "@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
  "@earendil-works/pi-ai": join(root, "node_modules/@earendil-works/pi-ai/dist/index.js"),
} });
const { default: idleRecap, recapFooter } = await loader.import(fileURLToPath(new URL("../extensions/idle-recap.ts", import.meta.url)));
const pi = await loader.import(join(root, "dist/index.js"));
const ai = await loader.import(join(root, "node_modules/@earendil-works/pi-ai/dist/index.js"));
const tui = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
pi.initTheme("dark");
const themeModule = await loader.import(join(root, "dist/modes/interactive/theme/theme.js"));
const recap = "Đã sửa renderer. Chưa commit/push; tiếp theo kiểm tra UI sau /reload.";
const answer = `Done.\n\n<pi_idle_recap status="done">\n${recap}\n</pi_idle_recap>`;
assert.deepEqual(recapFooter(answer), { body: "Done.", recap, status: "done" });
assert.equal(recapFooter(answer.replace(' status="done"', "")).status, "unknown");
assert.equal(recapFooter(answer.replace('status="done"', 'status="invalid"')).recap, undefined);
assert.deepEqual(recapFooter("plain answer"), { body: "plain answer" });
assert.equal(recapFooter(answer + "\n```").recap, undefined);
assert.equal(recapFooter("Done.\n<pi_idle_recap>\n" + "x".repeat(601) + "\n</pi_idle_recap>").recap, undefined);
const scratch = mkdtempSync(join(tmpdir(), "pi-idle-recap-"));
let session;
let renderer;
let transform;
const handlers = new Map();
const seen = [];
try {
  const agentDir = join(scratch, "agent");
  mkdirSync(agentDir);
  symlinkSync(fileURLToPath(new URL("../extensions", import.meta.url)), join(scratch, "extensions"), "dir");
  const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")).href);
  const loaded = await loadExtensions([join(scratch, "extensions/idle-recap.ts")], scratch);
  assert.deepEqual(loaded.errors, [], "Live symlink loader must load idle-recap");
  assert.equal(loaded.extensions.length, 1);
  const faux = ai.fauxProvider({ provider: "recap-fixture", models: [{ id: "fixture" }] });
  faux.setResponses(Array.from({ length: 5 }, () => context => { seen.push(structuredClone(context)); return ai.fauxAssistantMessage(answer); }));
  const settingsManager = pi.SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } });
  const resources = new pi.DefaultResourceLoader({
    cwd: scratch, agentDir, settingsManager, noExtensions: true, noContextFiles: true, noSkills: true, noPromptTemplates: true, noThemes: true,
    extensionFactories: [api => {
      api.registerProvider(faux.provider);
      idleRecap({ ...api,
        on: (name, handler) => { handlers.set(name, handler); return api.on(name, handler); },
        registerMessageRenderer: (name, render) => { renderer = render; api.registerMessageRenderer(name, render); },
        registerMarkdownTransformer: value => { transform = value; api.registerMarkdownTransformer(value); },
      });
    }],
  });
  await resources.reload();
  ({ session } = await pi.createAgentSession({ cwd: scratch, agentDir, settingsManager, resourceLoader: resources, sessionManager: pi.SessionManager.inMemory(scratch), model: faux.getModel(), tools: [] }));
  await session.bindExtensions({ mode: "tui", uiContext: { notify() {}, theme: themeModule.theme }, onError: error => { throw error; } });
  mock.timers.enable({ apis: ["setTimeout"] });
  const recaps = () => session.messages.filter(message => message.role === "custom" && message.customType === "idle-recap");
  await session.prompt("Finish the renderer.");
  assert.equal(seen.length, 1);
  assert.ok(JSON.stringify(seen[0]).includes("<pi_idle_recap status="));
  assert.ok(session.messages.some(message => message.role === "assistant" && message.content.some(block => block.type === "text" && block.text === answer)));
  assert.equal(transform(answer, { messageType: "assistant", isStreaming: false }), "Done.");
  assert.equal(transform(answer, { messageType: "user", isStreaming: false }), answer);
  mock.timers.tick(179999);
  assert.equal(recaps().length, 0);
  mock.timers.tick(1);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().length, 1);
  assert.equal(recaps()[0].content, recap);
  assert.equal(recaps()[0].details.status, "done");
  assert.equal(seen.length, 1, "Idle recap must not trigger another provider call");
  const { CustomMessageComponent } = await loader.import(join(root, "dist/modes/interactive/components/custom-message.js"));
  const component = new CustomMessageComponent(recaps()[0], renderer);
  const rendered = component.render(100).join("\n");
  assert.ok(tui.stripTerminalSequences(rendered).includes("󰋚 recap:"));
  assert.ok(rendered.includes(themeModule.theme.getFgAnsi("dim")));
  await session.prompt("Next step.");
  assert.equal(recaps().length, 1, "Posted recap must remain after new input");
  assert.ok(!JSON.stringify(seen[1].messages).includes('"customType":"idle-recap"'));
  assert.equal(JSON.stringify(seen[1].messages).split(recap).length - 1, 1, "Provider sees original assistant footer, not a duplicate UI recap");
  const projected = handlers.get("context")({ messages: session.messages });
  assert.ok(!projected.messages.some(message => message.role === "custom" && message.customType === "idle-recap"));
  handlers.get("input")({ text: "draft", source: "interactive" });
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().length, 1, "Input cancels pending recap, not posted recap");
  await session.prompt("Another milestone.");
  handlers.get("session_before_switch")({});
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().length, 1, "Pending recap must not leak across session navigation");
  await session.prompt("Interrupted milestone.");
  handlers.get("agent_settled")({ aborted: true }, { mode: "tui" });
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().length, 1, "Aborted run must not produce a completion recap");
  const ready = 'A slice finished.\n<pi_idle_recap status="ready">\nApproved verification remains; run the matched checks.\n</pi_idle_recap>';
  const blocked = 'Cannot proceed.\n<pi_idle_recap status="blocked">\nSDK delivery missing; owner must deliver BUILD + API. No independent approved work remains.\n</pi_idle_recap>';
  const respond = text => context => { seen.push(structuredClone(context)); return ai.fauxAssistantMessage(text); };
  faux.setResponses([respond(ready), respond(answer)]);
  let calls = seen.length;
  await session.prompt("Complete the approved checks.");
  assert.equal(seen.length - calls, 2, "Ready stop must get one native same-run continuation");
  assert.ok(JSON.stringify(seen.at(-1).messages).includes("You reported authorized ready work."));
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().at(-1).details.status, "done");
  assert.equal(seen.length - calls, 2, "Idle display must add no inference");
  faux.setResponses([respond(blocked)]);
  calls = seen.length;
  await session.prompt("Integrate the delivered SDK.");
  assert.equal(seen.length - calls, 1, "Blocked stops must not auto-continue");
  assert.ok(!JSON.stringify(seen.at(-1).messages).includes("You reported authorized ready work."), "Old stop-check must not leak into later tasks");
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  const blockedMessage = recaps().at(-1);
  assert.equal(blockedMessage.details.status, "blocked");
  assert.ok(tui.stripTerminalSequences(new CustomMessageComponent(blockedMessage, renderer).render(100).join("\n")).includes("󰋚 blocked:"));
  faux.setResponses([respond(ready), respond(ready), respond(answer)]);
  calls = seen.length;
  await session.prompt("Continue approved work.");
  assert.equal(seen.length - calls, 2, "Repeated ready stops must not create an unbounded continuation loop");
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(recaps().at(-1).details.status, "ready");
  assert.ok(recaps().at(-1).content.includes("Agent vẫn dừng"));
  faux.setResponses([respond("Plain final answer without a status.")]);
  calls = seen.length;
  await session.prompt("Return an exact plain answer.");
  assert.equal(seen.length - calls, 1);
  mock.timers.tick(180000);
  await new Promise(resolve => setImmediate(resolve));
  const unknown = recaps().at(-1);
  assert.equal(unknown.details.status, "unknown");
  assert.ok(unknown.content.includes("chưa xác định"));
  assert.ok(tui.stripTerminalSequences(new CustomMessageComponent(unknown, renderer).render(100).join("\n")).includes("󰋚 status:"));
  console.log("PASS: native symlink loader + real Pi AgentSession/faux provider; bounded ready rescue, three-minute idle without inference, persistent dim Pi status, lifecycle safety");
} finally {
  await session?.dispose();
  mock.timers.reset();
  rmSync(scratch, { recursive: true, force: true });
}
