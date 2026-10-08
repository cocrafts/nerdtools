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
const { FileHoverPreview, filePreview, diffPreview } = await loader.import(fileURLToPath(new URL("../extensions/neon-format/file-hover-preview.ts", import.meta.url)));
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
  const diffFixture = [
    ...Array.from({ length: 25 }, (_, i) => ` ${55 + i} const CONTEXT${55 + i} = 0;`),
    '-80 const label = "FIRST_OLD";', '+80 const label = "FIRST_NEW";',
    ...Array.from({ length: 18 }, (_, i) => ` ${81 + i} const tail${81 + i} = 0;`),
    "...", '-160 const later = "SECOND_OLD";', '+160 const later = "SECOND_NEW";',
  ].join("\n");
  const diffView = diffPreview(link, scratch, theme, diffFixture, 12, 80);
  const firstDiffRows = diffView.component.render(80);
  const firstDiff = tui.stripTerminalSequences(firstDiffRows.join("\n"));
  assert.ok(firstDiff.includes("FIRST_NEW"));
  assert.ok(!firstDiff.includes("CONTEXT55"), "Diff must start near the first change, not at file/context start");
  assert.ok(!firstDiff.includes("SECOND_NEW"));
  const addedBg = tui.backgroundAnsi(tui.mixColors(theme.colors.userMessageBg, theme.colors.toolDiffAdded, 0.12, "srgb"), tui.getTerminalColorMode());
  const removedBg = tui.backgroundAnsi(tui.mixColors(theme.colors.userMessageBg, theme.colors.toolDiffRemoved, 0.12, "srgb"), tui.getTerminalColorMode());
  assert.ok(firstDiffRows.join("\n").includes(addedBg) && firstDiffRows.join("\n").includes(removedBg), "Diff popup must preserve SyntaxDiff addition/removal backgrounds");
  diffView.component.handleMouse({ type: "wheel", wheelDelta: 100 });
  assert.ok(tui.stripTerminalSequences(diffView.component.render(80).join("\n")).includes("SECOND_NEW"));
  for (const width of [1, 3, 20, 80]) for (const row of diffView.component.render(width)) assert.ok(tui.visibleWidth(row) <= width);
  const wrappedContext = ` 1 ${"+4 ordinary_context ".repeat(80)}\n-2 const old = 1;\n+2 const ACTUAL_FIRST_CHANGE = 2;`;
  assert.ok(tui.stripTerminalSequences(diffPreview(link, scratch, theme, wrappedContext, 12, 40).component.render(40).join("\n")).includes("ACTUAL_FIRST_CHANGE"), "Wrapped context resembling a plus gutter must not be mistaken for a changed row");
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
  const editTool = pi.createEditTool(scratch);
  const editArgs = { path, edits: [
    { oldText: 'const value14: string = "line 14";', newText: 'const value14: string = "ALPHA_FIRST_EDIT";' },
    { oldText: 'const value28: string = "line 28";', newText: 'const value28: string = "OMEGA_FIRST_EDIT";' },
  ] };
  const edited = await editTool.execute("hover-edit-first", editArgs, undefined, () => {}, { cwd: scratch });
  const beforeEditPayload = JSON.stringify(edited);
  const editComponent = new pi.ToolExecutionComponent("edit", "hover-edit-first", editArgs, {}, resolver("edit", () => editTool), ui, scratch);
  layout.clear(); layout.addChild(editComponent); layout.addChild(editorContainer);
  ui.renderNow(true); mouse(10, 1); mock.timers.tick(350);
  assert.equal(ui.hasOverlay(), false, "Edit without a completed diff must not fall back to file-head preview");
  editComponent.updateResult(edited, true);
  ui.renderNow(true); mouse(10, 1); mock.timers.tick(350);
  assert.equal(ui.hasOverlay(), false, "Partial Edit result must not present a final diff");
  editComponent.updateResult(edited, false);
  writeFileSync(path, 'const current = "CURRENT_FILE_NOT_THIS_EDIT";');
  layout.clear(); layout.addChild(editComponent); layout.addChild(editorContainer);
  ui.renderNow(true);
  mouse(10, 1); mock.timers.tick(350); writes.length = 0; ui.renderNow(true);
  assert.equal(ui.hasOverlay(), true);
  assert.ok(tui.stripTerminalSequences(writes.join("")).includes("ALPHA_FIRST_EDIT"), "Hover must use this real Edit result, not the current file");
  assert.ok(!tui.stripTerminalSequences(writes.join("")).includes("CURRENT_FILE_NOT_THIS_EDIT"));
  assert.ok(!tui.stripTerminalSequences(writes.join("")).includes("OMEGA_FIRST_EDIT"), "Initial viewport stays at the first hunk");
  let sawSecondHunk = false;
  for (let i = 0; i < 12 && !sawSecondHunk; i++) {
    writes.length = 0; mouse(20, 8, 65); ui.renderNow(true);
    assert.equal(ui.hasOverlay(), true, "Wheel inside diff must scroll instead of closing popup");
    sawSecondHunk = tui.stripTerminalSequences(writes.join("")).includes("OMEGA_FIRST_EDIT");
  }
  assert.ok(sawSecondHunk, "Native wheel must reach the later hunk");
  assert.equal(ui.getFocusedComponent(), mode.editor);
  assert.equal(JSON.stringify(edited), beforeEditPayload, "Preview must not change tool/model payload");
  process.stdin.emit("data", "\x1b"); mock.timers.tick(10);
  const secondArgs = { path, edits: [{ oldText: "CURRENT_FILE_NOT_THIS_EDIT", newText: "SECOND_CALL_ONLY" }] };
  const secondResult = await editTool.execute("hover-edit-second", secondArgs, undefined, () => {}, { cwd: scratch });
  const secondComponent = new pi.ToolExecutionComponent("edit", "hover-edit-second", secondArgs, {}, resolver("edit", () => editTool), ui, scratch);
  secondComponent.updateResult(secondResult, false);
  layout.clear(); layout.addChild(editComponent); layout.addChild(secondComponent); layout.addChild(editorContainer);
  ui.renderNow(true);
  mouse(10, 1); mock.timers.tick(350); writes.length = 0; ui.renderNow(true);
  assert.ok(tui.stripTerminalSequences(writes.join("")).includes("ALPHA_FIRST_EDIT"));
  assert.ok(!tui.stripTerminalSequences(writes.join("")).includes("SECOND_CALL_ONLY"), "Later same-file Edit must not replace earlier call's diff");
  process.stdin.emit("data", "\x1b"); mock.timers.tick(10);
  editComponent.updateResult({ content: [{ type: "text", text: "Edit failed" }], details: edited.details, isError: true }, false);
  ui.renderNow(true); mouse(10, 1); mock.timers.tick(350);
  assert.equal(ui.hasOverlay(), false, "Failed Edit must clear stale successful diff preview");
  const writeTool = pi.createWriteTool(scratch);
  const writeArgs = { path: join(scratch, "written.ts"), content: 'const written = "WRITE_CONTENT_PREVIEW";' };
  const written = await writeTool.execute("hover-write", writeArgs, undefined, () => {}, { cwd: scratch });
  const writeComponent = new pi.ToolExecutionComponent("write", "hover-write", writeArgs, {}, resolver("write", () => writeTool), ui, scratch);
  writeComponent.updateResult(written, false);
  layout.clear(); layout.addChild(writeComponent); layout.addChild(editorContainer);
  ui.renderNow(true); mouse(10, 1); mock.timers.tick(350); writes.length = 0; ui.renderNow(true);
  assert.ok(tui.stripTerminalSequences(writes.join("")).includes("WRITE_CONTENT_PREVIEW"), "Write hover keeps file content, not Edit diff mode");
  process.stdin.emit("data", "\x1b"); mock.timers.tick(10);
  for (const hook of hooks.get("session_shutdown")) await hook({ reason: "reload" }, liveCtx);
  assert.equal(process.stdin.listenerCount("data"), baseline + 1, "Extension reload cleans preview and focus observers");
  console.log("PASS: actual extension/native editor + raw SGR hover; exact real Edit snapshot at first changed hunk, SyntaxDiff colors/backgrounds, wheel to later hunk; same-file calls isolated, payload unchanged, partial/error cleared; Read window/read safety, focus/draft/dialogs/click and reload cleanup preserved");
} finally {
  cleanupExtension();
  preview.close();
  ui.stop();
  nativeInput.destroy();
  assert.equal(process.stdin.listenerCount("data"), baseline, "Preview must clean up its non-consuming observer");
  mock.timers.reset();
  rmSync(scratch, { recursive: true, force: true });
}
