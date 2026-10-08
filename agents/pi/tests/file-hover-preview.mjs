import assert from "node:assert/strict";
import { mock } from "node:test";
import { createRequire } from "node:module";
import { mkdtempSync, writeFileSync, symlinkSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
  "@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
  "@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
} });
const { FileHoverPreview, filePreview } = await loader.import(fileURLToPath(new URL("../extensions/neon-format/file-hover-preview.ts", import.meta.url)));
const { ToolCallLine, default: neonFormat } = await loader.import(fileURLToPath(new URL("../extensions/neon-format/index.ts", import.meta.url)));
const pi = await loader.import(join(root, "dist/index.js"));
const tui = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
pi.initTheme("dark");
const { theme } = await loader.import(join(root, "dist/modes/interactive/theme/theme.js"));
const { KeybindingsManager } = await loader.import(join(root, "dist/core/keybindings.js"));
const scratch = mkdtempSync(join(tmpdir(), "pi-hover-preview-"));
const writes = [];
let input;
const nativeInput = new tui.StdinBuffer();
const feedNative = chunk => nativeInput.process(chunk);
nativeInput.on("data", data => input(data));
nativeInput.on("paste", text => input(`\x1b[200~${text}\x1b[201~`));
const baseline = process.stdin.listenerCount("data");
const terminal = { rows: 30, columns: 100, kittyProtocolActive: false, write: text => writes.push(text), start: handler => { input = handler; process.stdin.on("data", feedNative); }, stop() { process.stdin.off("data", feedNative); }, hideCursor() {}, showCursor() {} };
const ui = new tui.TuiAltScreen(terminal, false);
const editor = new pi.CustomEditor(ui, { borderColor: text => text, selectList: {} }, new KeybindingsManager({}));
let context = { mode: "tui", cwd: scratch, ui: { theme, onTerminalInput: handler => ui.addInputListener(handler) } };
const preview = new FileHoverPreview(() => context, () => ui);
let cleanupExtension = () => {};
try {
  const path = join(scratch, "example.ts");
  writeFileSync(path, Array.from({ length: 30 }, (_, index) => `const value${index + 1}: string = "line ${index + 1}";`).join("\n"));
  const link = { path, line: 15 };
  const view = filePreview(link, scratch, theme);
  const rows = view.component.render(80);
  assert.equal(rows.length, 15);
  assert.ok(tui.stripTerminalSequences(rows.join("\n")).includes("example.ts:15"));
  assert.ok(tui.stripTerminalSequences(rows.join("\n")).includes('value15: string = "line 15"'));
  assert.ok(rows.join("\n").includes(pi.highlightCode('const value15: string = "line 15";', "typescript").join("\n")), "Preview must retain native token colors, not merely a colored border");
  for (const width of [1, 3, 20, 80]) for (const row of view.component.render(width)) assert.ok(tui.visibleWidth(row) <= width);
  symlinkSync(process.execPath, join(scratch, "outside.ts"));
  assert.ok(tui.stripTerminalSequences(filePreview({ path: join(scratch, "outside.ts") }, scratch, theme).component.render(80).join("\n")).includes("outside workspace"));
  writeFileSync(join(scratch, "large.ts"), "x".repeat(256 * 1024 + 1));
  assert.ok(tui.stripTerminalSequences(filePreview({ path: join(scratch, "large.ts") }, scratch, theme).component.render(80).join("\n")).includes("256 KiB"));
  writeFileSync(join(scratch, "binary.ts"), Buffer.from([0, 1, 2]));
  assert.ok(tui.stripTerminalSequences(filePreview({ path: join(scratch, "binary.ts") }, scratch, theme).component.render(80).join("\n")).includes("Binary file"));
  let clicks = 0;
  const header = new ToolCallLine(" Read", "example.ts", ":15", theme, link, () => { preview.close(); clicks++; }, undefined, (link, event, start, end) => preview.hover(link, event, start, end));
  const layout = new tui.Container();
  layout.addChild(header);
  layout.addChild(editor);
  ui.setLayoutRoot(layout);
  ui.setFocus(editor);
  editor.setText("unchanged draft");
  ui.start();
  mock.timers.enable({ apis: ["setTimeout"] });
  ui.renderNow(true);
  const mouse = (x, y, code = 35) => process.stdin.emit("data", `\x1b[<${code};${x + 1};${y + 1}M`);
  mouse(10, 0);
  mock.timers.tick(349);
  assert.equal(ui.hasOverlay(), false);
  mock.timers.tick(1);
  assert.equal(ui.hasOverlay(), true, "Native SGR hover over header must open public overlay after 350ms");
  ui.renderNow(true);
  assert.equal(ui.getFocusedComponent(), editor);
  assert.equal(editor.getText(), "unchanged draft");
  assert.ok(writes.join("").includes("example.ts:15"));
  mouse(12, 2);
  assert.equal(ui.hasOverlay(), true, "Moving into preview must keep it open");
  process.stdin.emit("data", "\x1b[<35;");
  process.stdin.emit("data", "100;30M");
  assert.equal(ui.hasOverlay(), false, "Split mouse report leaving filename and preview closes it");
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  input("\x1b");
  assert.equal(ui.hasOverlay(), false);
  assert.equal(editor.getText(), "unchanged draft");
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  input("x");
  assert.equal(ui.hasOverlay(), false);
  assert.equal(editor.getText(), "unchanged draftx", "Typing must still reach editor");
  mouse(10, 0); mock.timers.tick(200); mouse(99, 29); mock.timers.tick(150);
  assert.equal(ui.hasOverlay(), false, "Leaving before deadline cancels pending hover");
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  let otherEsc = 0;
  const other = ui.showOverlay({ render: width => new tui.Text("Other dialog").render(width), invalidate() {}, handleInput: data => { if (tui.matchesKey(data, "escape")) otherEsc++; } });
  ui.renderNow(true);
  process.stdin.emit("data", "\x1b"); mock.timers.tick(10);
  assert.equal(otherEsc, 1, "Preview must not steal Escape from a newly focused dialog");
  preview.close();
  assert.equal(ui.hasOverlay(), true, "Closing owned preview must not remove another dialog");
  other.hide();
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  mouse(10, 0, 0);
  process.stdin.emit("data", "\x1b[<0;11;1m");
  assert.equal(clicks, 1);
  assert.equal(ui.hasOverlay(), false);
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  process.stdin.emit("data", "\x1b[O");
  assert.equal(ui.hasOverlay(), false, "Terminal blur closes preview without consuming focus routing");
  mouse(10, 0); context = undefined; mock.timers.tick(350);
  assert.equal(ui.hasOverlay(), false, "Stale session must not open a preview");
  const { InteractiveMode } = await loader.import(join(root, "dist/modes/interactive/interactive-mode.js"));
  const editorContainer = new tui.Container();
  editorContainer.addChild(editor);
  const mode = { defaultEditor: editor, editor, ui, editorContainer, keybindings: new KeybindingsManager({}), disposeActiveSelector() {}, autocompleteProvider: new tui.CombinedAutocompleteProvider([], scratch) };
  const hooks = new Map();
  let resolver;
  const liveCtx = {
    mode: "tui", cwd: scratch, isIdle: () => false, sessionManager: { getSessionId: () => "native-hover-integration" },
    ui: {
      theme, onTerminalInput: handler => ui.addInputListener(handler),
      getEditorText: () => mode.editor.getExpandedText(),
      setEditorText: text => mode.editor.setText(text),
      setEditorComponent: factory => InteractiveMode.prototype.setCustomEditorComponent.call(mode, factory),
      notify: message => { throw new Error(message); },
    },
  };
  neonFormat({
    getCommands: () => [], events: pi.createEventBus(), registerMarkdownTransformer() {},
    on: (name, handler) => { const entries = hooks.get(name) ?? []; entries.push(handler); hooks.set(name, entries); },
    registerToolRenderer: value => { resolver = value; },
  });
  cleanupExtension = () => { for (const hook of hooks.get("session_shutdown")) hook({ reason: "reload" }, liveCtx); };
  for (const hook of hooks.get("session_start")) await hook({}, liveCtx);
  const actualHeader = resolver("read", () => undefined).renderCall({ path, offset: 15 }, theme, { cwd: scratch, state: {}, argsComplete: true });
  layout.clear(); layout.addChild(actualHeader); layout.addChild(editorContainer);
  ui.renderNow(true);
  mouse(10, 0); mock.timers.tick(350); ui.renderNow(true);
  assert.equal(ui.hasOverlay(), true, "Actual extension resolver + native editor factory must open hover preview");
  assert.equal(ui.getFocusedComponent(), mode.editor);
  process.stdin.emit("data", "\x1b"); mock.timers.tick(10);
  assert.equal(ui.hasOverlay(), false);
  for (const hook of hooks.get("session_shutdown")) await hook({ reason: "reload" }, liveCtx);
  assert.equal(process.stdin.listenerCount("data"), baseline + 1, "Extension reload cleans preview and focus observers");
  console.log("PASS: actual extension resolver/native editor factory + TuiAltScreen SGR hover → 350ms overlay; native syntax colors, line window, safe bounded reads; pointer/ESC/typing cancellation, focus/draft and other dialogs preserved, click unchanged, stale session/reload cleanup");
} finally {
  cleanupExtension();
  preview.close();
  ui.stop();
  nativeInput.destroy();
  assert.equal(process.stdin.listenerCount("data"), baseline, "Preview must clean up its non-consuming observer");
  mock.timers.reset();
  rmSync(scratch, { recursive: true, force: true });
}
