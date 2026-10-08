import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const scratch = mkdtempSync(join(tmpdir(), "pi-peer-render-"));
const home = process.env.HOME;
const explicitName = process.env.CC_PEER_NAME;
process.env.HOME = scratch;
delete process.env.CC_PEER_NAME;
const loader = createJiti(import.meta.url, { alias: {
  "@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
  "@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
  "typebox": require.resolve("typebox"),
} });
const { default: ccPeer, keyHashForToken } = await loader.import(fileURLToPath(new URL("../extensions/cc-peer.ts", import.meta.url)));
const pi = await loader.import(join(root, "dist/index.js"));
const tui = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
pi.initTheme("dark");
const themeModule = await loader.import(join(root, "dist/modes/interactive/theme/theme.js"));
const handlers = new Map();
const tools = new Map();
let renderer;
let currentName = "Pi Architect";
const api = {
  on: (name, handler) => handlers.set(name, handler),
  getSessionName: () => currentName,
  registerMessageRenderer: (_name, render) => renderer = render,
  registerTool: tool => tools.set(tool.name, tool),
};
const ctx = { cwd: scratch, hasUI: false, sessionManager: { getSessionId: () => "peer-render-test" } };
const server = createServer();
try {
  await ccPeer(api);
  const content = '<cross-session-message from="uds:/tmp/test.sock" from-name="void-manager" from-mode="bypass">\nRight call on both.\nRerun the pair and record BUILD.\n</cross-session-message>';
  const message = { content };
  for (const width of [1, 2, 3, 8, 30, 80, 200]) {
    const rows = renderer(message, { expanded: false }, themeModule.theme).render(width);
    assert.ok(rows.length <= 3);
    for (const row of rows) {
      assert.ok(tui.visibleWidth(row) <= width);
      if (width > 2) {
        const plainRow = tui.stripTerminalSequences(row);
        assert.ok(plainRow.startsWith(" ") && plainRow.endsWith(" "), "Peer rows need one-space outer padding");
      }
    }
    assert.ok(!rows[0].includes("cross-session-message"));
  }
  const collapsed = tui.stripTerminalSequences(renderer(message, { expanded: false }, themeModule.theme).render(200).join("\n"));
  assert.ok(collapsed.startsWith(" › Message from @void-manager: Right call on both."));
  assert.ok(!collapsed.includes("to expand"), "Short messages must not show an expand hint");
  const expanded = tui.stripTerminalSequences(renderer(message, { expanded: true }, themeModule.theme).render(80).join("\n"));
  assert.ok(expanded.includes("Rerun the pair and record BUILD."));
  assert.ok(!expanded.includes("from-mode"));
  assert.ok(!expanded.includes("cross-session-message"));
  assert.equal(message.content, content);
  const malicious = { content: '<cross-session-message from-name="bad\n\u001b[31mname">\nbody\n</cross-session-message>' };
  assert.ok(renderer(malicious, { expanded: false }, themeModule.theme).render(80).length <= 3);
  const longMessage = { customType: "cc-peer.message", content: '<cross-session-message from-name="void-manager">\n' + Array.from({ length: 9 }, (_, index) => `body row ${index}`).join("\n") + '\n</cross-session-message>' };
  const { CustomMessageComponent } = await loader.import(join(root, "dist/modes/interactive/components/custom-message.js"));
  const native = new CustomMessageComponent(longMessage, renderer);
  assert.equal(native.render(80).length, 4, "Native spacer plus three preview rows");
  assert.ok(tui.stripTerminalSequences(native.render(80).join("\n")).includes("…"));
  assert.ok(!tui.stripTerminalSequences(native.render(80).join("\n")).includes("to expand"));
  const click = { type: "click", button: "left", x: 4, y: 1, screenX: 4, screenY: 1, width: 80, height: 4, shift: false, alt: false, ctrl: false };
  assert.equal(native.handleMouse(click).handled, true);
  native.invalidate();
  assert.ok(native.render(80).length > 4, "Click expansion must survive native invalidation/rebuild");
  assert.ok(tui.stripTerminalSequences(native.render(80).join("\n")).includes("body row 8"));
  native.setExpanded(true);
  native.setExpanded(false);
  assert.equal(native.render(80).length, 4, "Native keyboard collapse must override local click state");
  assert.equal(native.handleMouse(click).handled, true);
  native.render(80);
  assert.equal(native.handleMouse(click).handled, true);
  assert.equal(native.render(80).length, 4, "Second click collapses the preview");
  await handlers.get("session_start")({}, ctx);
  const registry = join(scratch, ".claude", "sessions");
  const ownEntry = join(registry, `${process.pid}.json`);
  assert.equal(JSON.parse(readFileSync(ownEntry)).name, currentName);
  currentName = "Renamed Architect";
  handlers.get("session_info_changed")({ name: currentName }, ctx);
  assert.equal(JSON.parse(readFileSync(ownEntry)).name, currentName);
  handlers.get("agent_start")({}, ctx);
  assert.equal(JSON.parse(readFileSync(ownEntry)).name, currentName);
  const token = "peer-render-test-token";
  const socketPath = join(scratch, "receiver.sock");
  mkdirSync(registry, { recursive: true });
  writeFileSync(join(registry, `${process.ppid}.json`), JSON.stringify({ name: "receiver", messagingSocketPath: socketPath }));
  writeFileSync(join(registry, `${process.ppid}.${keyHashForToken(token)}.key`), JSON.stringify({ peerToken: token }));
  const received = new Promise(resolve => server.on("connection", socket => {
    let data = "";
    socket.on("data", chunk => data += chunk);
    socket.on("end", () => resolve(data));
  }));
  await new Promise(resolve => server.listen(socketPath, resolve));
  const sendTool = tools.get("cc_send_message");
  const sendArgs = { to: `receiver [${process.ppid}]`, message: "body untouched\n" + Array.from({ length: 9 }, (_, index) => `outgoing row ${index}`).join("\n") };
  const sent = await sendTool.execute("test", sendArgs, undefined, undefined, ctx);
  const beforeSent = JSON.stringify(sent);
  const outgoing = new pi.ToolExecutionComponent("cc_send_message", "test", sendArgs, {}, sendTool, { requestRender() {} }, scratch);
  outgoing.setArgsComplete();
  outgoing.updateResult(sent, false);
  const outgoingRows = tui.stripTerminalSequences(outgoing.render(80).join("\n"));
  assert.ok(outgoingRows.includes("› Message to @receiver: body untouched"));
  assert.ok(outgoingRows.includes("…"));
  assert.ok(!outgoingRows.includes("to expand"));
  assert.ok(!outgoingRows.includes("msg_id"));
  assert.ok(!outgoingRows.includes("cc_send_message"));
  const outgoingClick = { ...click, y: 1 };
  assert.equal(outgoing.handleMouse(outgoingClick)?.handled, true);
  assert.ok(tui.stripTerminalSequences(outgoing.render(80).join("\n")).includes("outgoing row 8"));
  outgoing.setExpanded(true);
  outgoing.setExpanded(false);
  assert.ok(!tui.stripTerminalSequences(outgoing.render(80).join("\n")).includes("outgoing row 8"));
  outgoing.updateResult({ content: [{ type: "text", text: "peer refused" }], details: {}, isError: true }, false);
  assert.ok(outgoing.render(80).join("\n").includes(themeModule.theme.fg("error", "peer refused")));
  assert.equal(JSON.stringify(sent), beforeSent);
  const frames = (await received).trim().split("\n").map(line => JSON.parse(line));
  assert.equal(frames[0].token, token);
  assert.ok(frames[1].message.content.includes('from-name="Renamed Architect"'));
  assert.ok(frames[1].message.content.includes("body untouched"));
  handlers.get("session_info_changed")({ name: undefined }, ctx);
  assert.equal(JSON.parse(readFileSync(ownEntry)).name, `pi-${process.pid}`);
  console.log("PASS: peer preview max three rows, ellipsis only on overflow, no expand hint, native mouse expansion survives rebuild, keyboard/click collapse; clean body and model payload preserved; rename updates registry and authenticated wire identity");
} finally {
  handlers.get("session_shutdown")?.({}, ctx);
  await new Promise(resolve => server.listening ? server.close(resolve) : resolve());
  if (home === undefined) delete process.env.HOME; else process.env.HOME = home;
  if (explicitName === undefined) delete process.env.CC_PEER_NAME; else process.env.CC_PEER_NAME = explicitName;
  rmSync(scratch, { recursive: true, force: true });
}
