import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
	"@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
	"@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
} });
const { registerSkillInput } = await loader.import(fileURLToPath(new URL("../extensions/neon-format/skill-input.ts", import.meta.url)));
const pi = await loader.import(join(root, "dist/index.js"));
const tui = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
const { KeybindingsManager } = await loader.import(join(root, "dist/core/keybindings.js"));
const { InteractiveMode } = await loader.import(join(root, "dist/modes/interactive/interactive-mode.js"));
pi.initTheme("dark");
const themeModule = await loader.import(join(root, "dist/modes/interactive/theme/theme.js"));
const keys = new KeybindingsManager({});
const editorTheme = { borderColor: text => text, selectList: {} };
const tick = () => new Promise(resolve => setTimeout(resolve, 40));
const baseline = process.stdin.listenerCount("data");
const writes = [];
const nativeInput = new tui.StdinBuffer();
let nativeHandler;
const feedNative = chunk => nativeInput.process(chunk);
const terminal = {
	rows: 24, columns: 80, kittyProtocolActive: false,
	write: data => writes.push(data), hideCursor() {}, showCursor() {},
	start(handler) {
		nativeHandler = handler;
		process.stdin.on("data", feedNative);
	},
	stop() { process.stdin.off("data", feedNative); },
};
nativeInput.on("data", data => nativeHandler(data));
nativeInput.on("paste", text => nativeHandler(`\x1b[200~${text}\x1b[201~`));
const fullscreen = process.env.PI_FOCUS_TEST_MODE !== "regular";
const ui = new (fullscreen ? tui.TuiAltScreen : tui.TuiMainScreen)(terminal, false);
let hookReports = 0;
ui.addInputListener(data => { if (data === "\x1b[I" || data === "\x1b[O") hookReports++; });
const defaultEditor = new pi.CustomEditor(ui, editorTheme, keys);
const container = new tui.Container();
container.addChild(defaultEditor);
ui.addChild(container);
ui.setFocus(defaultEditor);
const mode = {
	defaultEditor, editor: defaultEditor, ui, keybindings: keys, editorContainer: container,
	disposeActiveSelector() {}, autocompleteProvider: new tui.CombinedAutocompleteProvider([], process.cwd()),
};
const handlers = new Map();
const ctx = {
	hasPendingMessages: () => false, mode: "tui", sessionManager: { getSessionId: () => "focus-test" },
	ui: {
		get theme() { return themeModule.theme; },
		getEditorText: () => mode.editor.getExpandedText(),
		setEditorText: text => mode.editor.setText(text),
		setEditorComponent: factory => InteractiveMode.prototype.setCustomEditorComponent.call(mode, factory),
		notify: text => { throw new Error(text); },
	},
};
const feed = data => process.stdin.emit("data", data);
const frame = () => { writes.length = 0; ui.renderNow(true); return writes.join(""); };
const cursorBackground = themeModule.theme.style("cursor", { bg: themeModule.theme.colors.muted }).split("cursor")[0];
const focused = () => {
	assert.ok(frame().includes(cursorBackground));
	const rows = mode.editor.render(80);
	for (const row of [rows[0], rows.at(-1)]) assert.equal(row, themeModule.theme.style(tui.stripTerminalSequences(row), { fg: tui.parseColor("#89b4fa") }), "Focused input border must match Herdr blue");
};
const dimmed = () => {
	for (const row of mode.editor.render(80)) assert.equal(row, themeModule.theme.fg("dim", tui.stripTerminalSequences(row)), "Unfocused input border and all text, including skill chips, must be dim");
};
const blurred = () => {
	assert.ok(!frame().includes(cursorBackground), "Window focus-out must remove the software cursor while editor remains focused");
	dimmed();
};
try {
	const getTui = registerSkillInput({ getCommands: () => [{ source: "skill", name: "skill:focus-probe", sourceInfo: { path: "/tmp/focus-probe-skill/SKILL.md" } }], on: (name, handler) => handlers.set(name, handler), registerMarkdownTransformer() {}, events: pi.createEventBus() });
	assert.equal(getTui(), undefined);
	ui.start();
	await handlers.get("session_start")({}, ctx);
	assert.equal(getTui(), ui, "Hover preview must receive the native editor TUI");
	assert.equal(writes.includes("\x1b[?1004h"), !fullscreen, "Only regular mode must enable its own focus reporting");
	mode.editor.setText("draft /skill:focus-probe");
	assert.ok(mode.editor.getText().includes(" focus-probe"));
	mode.editor.borderColor = text => themeModule.theme.fg("thinkingHigh", text);
	focused();
	const dialog = ui.showOverlay(new tui.Text("dialog", 0, 0), { width: 20 });
	assert.equal(mode.editor.focused, false);
	dimmed();
	dialog.hide(); focused();
	const before = mode.editor.getDraft();
	writes.length = 0;
	feed("\x1b[O");
	await tick();
	assert.ok(writes.length > 0, "Window focus-out must request a redraw");
	assert.equal(mode.editor.focused, true);
	blurred();
	assert.deepEqual(mode.editor.getDraft(), before);
	feed("\x1b[I"); focused();
	feed("\x1b["); feed("O"); blurred();
	feed("\x1b[I\x1b[O"); blurred();
	feed("\x1b[I"); focused();
	feed("\x1b[200~literal \x1b[O\x1b[201~"); focused();
	if (fullscreen) assert.equal(hookReports, 0, "Native fullscreen consumes focus before public input hooks");
	else assert.ok(hookReports > 0);
	const count = process.stdin.listenerCount("data");
	await handlers.get("session_shutdown")({ reason: "reload" }, ctx);
	assert.equal(getTui(), undefined, "Shutdown must release the preview TUI reference");
	assert.equal(process.stdin.listenerCount("data"), count - 1, "Reload must remove the raw focus observer");
	assert.equal(writes.includes("\x1b[?1004l"), !fullscreen, "Only regular mode must disable its owned focus reporting");
	await handlers.get("session_start")({}, ctx);
	assert.equal(process.stdin.listenerCount("data"), count, "Reload must restore only one observer");
	feed("\x1b[O"); blurred();
	feed("\x1b[I"); focused();
	console.log(`PASS terminal focus (${fullscreen ? "fullscreen" : "regular"}): Herdr-blue border overrides effort color; terminal and dialog blur dim border/text/chips; native routing, cursor, redraw, split/batched reports, paste isolation, draft preservation, reload cleanup`);
} finally {
	await handlers.get("session_shutdown")?.({ reason: "shutdown" }, ctx);
	ui.stop(); nativeInput.destroy();
	assert.equal(process.stdin.listenerCount("data"), baseline);
}
