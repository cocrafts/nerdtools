import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { mkdtempSync, rmSync, writeFileSync, unlinkSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const agentPath = join(root, "dist/index.js");
const tuiPath = join(root, "node_modules/@earendil-works/pi-tui/dist/index.js");
const jiti = createJiti(import.meta.url, { alias: { "@earendil-works/pi-coding-agent": agentPath, "@earendil-works/pi-tui": tuiPath } });
const helper = await jiti.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format/skill-input.ts"));
const submit = await jiti.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format/skill-submit.ts"));
const pi = await import(pathToFileURL(agentPath).href);
const tui = await import(pathToFileURL(tuiPath).href);
const themeModule = await import(pathToFileURL(join(root, "dist/modes/interactive/theme/theme.js")).href);
const { KeybindingsManager } = await import(pathToFileURL(join(root, "dist/core/keybindings.js")).href);
const { InteractiveMode } = await import(pathToFileURL(join(root, "dist/modes/interactive/interactive-mode.js")).href);
pi.initTheme("dark");
const editorTheme = { borderColor: text => text, selectList: Object.fromEntries(["selectedPrefix", "selectedText", "description", "scrollInfo", "noMatch"].map(key => [key, text => text])) };
const fakeTui = { terminal: { rows: 40, write() {} }, setFocus(editor) { editor.focused = true; }, requestRender() {} };
const keys = new KeybindingsManager({});
const defaultEditor = new pi.CustomEditor(fakeTui, editorTheme, keys, { embedWorkingStatus: true });
let submitted;
defaultEditor.onSubmit = text => submitted = text;
defaultEditor.onChange = () => {};
let appCalls = 0;
defaultEditor.actionHandlers.set("app.model.cycleForward", () => appCalls++);
const mode = { defaultEditor, editor: defaultEditor, ui: fakeTui, keybindings: keys, editorContainer: new tui.Container(), disposeActiveSelector() {}, autocompleteProvider: new tui.CombinedAutocompleteProvider([{ name: "skill:trace-nim" }, { name: "skill:split-commit" }, { name: "model" }], process.cwd()) };
const errors = [];
const ctx = { mode: "tui", sessionManager: { getSessionId: () => "skill-test" }, ui: {
	get theme() { return themeModule.theme; },
	getEditorText: () => mode.editor.getExpandedText(), setEditorText: text => mode.editor.setText(text),
	setEditorComponent: factory => InteractiveMode.prototype.setCustomEditorComponent.call(mode, factory),
	notify: (text, kind) => errors.push({ text, kind }),
} };
const scratch = mkdtempSync(join(tmpdir(), "pi-atomic-input-"));
const bus = new EventEmitter();
const events = { on: (name, fn) => { bus.on(name, fn); return () => bus.off(name, fn); }, emit: (name, data) => bus.emit(name, data) };
const files = new Map(["trace-nim", "split-commit"].map(name => {
	const path = join(scratch, `${name}.md`);
	writeFileSync(path, `---\nname: ${name}\ndescription: fixture\n---\nBody ${name}. A literal /skill:split-commit in this file must not be rescanned.\n`);
	return [name, path];
}));
let handlers;
let markdown;
const register = () => {
	handlers = new Map();
	helper.registerSkillInput({ getCommands: () => [...files].map(([name, path]) => ({ source: "skill", name: `skill:${name}`, sourceInfo: { path } })), on: (name, fn) => handlers.set(name, fn), events, registerMarkdownTransformer: fn => markdown = fn });
};
const plain = tui.stripTerminalSequences;
const tick = () => new Promise(resolve => setTimeout(resolve, 40));
try {
	register();
	const longPaste = "preserve pasted draft\n".repeat(80);
	defaultEditor.handleInput(`\x1b[200~${longPaste}\x1b[201~`);
	await handlers.get("session_start")({}, ctx);
	let editor = mode.editor;
	assert.equal(editor.getExpandedText(), longPaste);
	assert.equal(editor.onSubmit, defaultEditor.onSubmit);
	assert.equal(editor.onChange, defaultEditor.onChange);
	assert.equal(editor.actionHandlers.get("app.model.cycleForward"), defaultEditor.actionHandlers.get("app.model.cycleForward"));
	for (const text of ["", "abc", "/skill:trace-nim", "ab\ncd"]) {
		editor.setText(text);
		const draft = editor.getDraft();
		for (const cursor of [0, draft.text.length]) {
			editor.restoreDraft({ ...draft, cursor });
			for (const width of [1, 2, 8, 80]) {
				editor.focused = false;
				const blurred = editor.render(width).join("\n");
				assert.ok(!blurred.includes(themeModule.theme.style("cursor", { bg: themeModule.theme.colors.muted }).split("cursor")[0]), "Blurred input must not draw a cursor block");
				assert.ok(!blurred.includes(tui.CURSOR_MARKER), "Blurred input must not expose a hardware cursor marker");
				editor.focused = true;
				const focused = editor.render(width).join("\n");
				assert.ok(focused.includes(themeModule.theme.style("cursor", { bg: themeModule.theme.colors.muted }).split("cursor")[0]) && focused.includes(tui.CURSOR_MARKER), "Focused input must restore its cursor block");
				assert.equal(editor.getDraft().cursor, cursor, "Focus changes must preserve cursor position");
			}
		}
	}
	const original = "Review /skill:trace-nim rồi /skill:split-commit";
	editor.setText(original);
	assert.equal(editor.getText(), "Review  trace-nim rồi  split-commit");
	assert.equal(editor.getExpandedText(), original);
	for (const width of [1, 2, 8, 20, 40, 80, 120]) for (const padding of [0, 2]) {
		editor.setPaddingX(padding);
		for (const line of editor.render(width)) assert.ok(tui.visibleWidth(line) <= width, `${width}: ${plain(line)}`);
	}
	editor.setPaddingX(0); editor.render(80);
	const event = { type: "click", button: "left", x: 11, y: 1, screenX: 11, screenY: 1, width: 80, height: 3, shift: false, alt: false, ctrl: false };
	assert.equal(editor.handleMouse(event).handled, true);
	assert.equal(editor.getCursor().col, 11);
	assert.equal(editor.handleMouse({ ...event, type: "drag" }), undefined);
	editor.handleInput("\x7f");
	assert.equal(editor.getText(), "Review  rồi  split-commit");
	editor.handleInput("\x1f");
	assert.equal(editor.getExpandedText(), original);
	editor.setText(original); editor.handleInput("\r");
	assert.equal(submitted, original);
	assert.equal(editor.getText(), "");
	const transformed = await handlers.get("input")({ text: submitted, source: "interactive" }, ctx);
	assert.equal(transformed.action, "transform");
	assert.equal((transformed.text.match(/<skill name=/g) ?? []).length, 2);
	assert.ok(transformed.text.indexOf('name="trace-nim"') < transformed.text.indexOf('name="split-commit"'));
	assert.ok(transformed.text.endsWith(original));
	assert.ok(!transformed.text.includes("description: fixture"));
	const first = pi.parseSkillBlock(transformed.text);
	assert.equal(first.name, "trace-nim");
	assert.equal(markdown(first.userMessage, { messageType: "user" }), "Review  trace-nim rồi  split-commit");
	assert.equal(markdown(first.userMessage, { messageType: "assistant" }), first.userMessage);
	assert.equal(await handlers.get("input")({ text: original, source: "extension" }, ctx), undefined);
	for (const text of ["!echo /skill:trace-nim", "/model /skill:trace-nim", "Use /skill:missing", "Use `/skill:trace-nim` literally"]) assert.equal(await handlers.get("input")({ text, source: "interactive" }, ctx), undefined);
	assert.equal(submit.skillPromptInput(transformed.text), original);
	editor.addToHistory(transformed.text);
	editor.handleInput("\x1b[A"); assert.equal(editor.getExpandedText(), original);
	editor.handleInput("\x1b[B"); assert.equal(editor.getText(), "");
	editor.setText("Review "); editor.handleInput("/");
	await tick(); assert.equal(editor.isShowingAutocomplete(), true, "Inline slash must open the skill menu");
	assert.ok(plain(editor.render(80).join("\n")).includes("/skill:trace-nim"));
	editor.handleInput("tra"); await tick();
	assert.equal(editor.isShowingAutocomplete(), true, "Inline slash must filter skill names");
	editor.handleInput("\t");
	assert.equal(editor.getExpandedText(), "Review /skill:trace-nim ");
	editor.handleInput("then /"); await tick();
	assert.equal(editor.isShowingAutocomplete(), true, "Inline slash must work after an existing chip");
	editor.handleInput("split"); await tick(); editor.handleInput("\t");
	assert.equal(editor.getExpandedText(), "Review /skill:trace-nim then /skill:split-commit ");
	editor.setText("Review /skill:tra"); editor.handleInput("\t"); await tick();
	if (editor.isShowingAutocomplete()) editor.handleInput("\t");
	assert.equal(editor.getText(), "Review  trace-nim ");
	assert.equal(editor.getExpandedText(), "Review /skill:trace-nim ");
	editor.handleInput("\x1f"); assert.equal(editor.getText(), "Review /skill:tra");
	editor.setText("");
	for (const char of "Review /skill:trace-nim then ") editor.handleInput(char);
	assert.equal(editor.getText(), "Review  trace-nim then ");
	editor.setText("/mo"); editor.handleInput("\t"); await tick();
	if (editor.isShowingAutocomplete()) editor.handleInput("\t");
	assert.equal(editor.getText().trim(), "/model");
	editor.setText("before"); editor.handleInput("\x10"); assert.equal(appCalls, 1);
	editor.setText("abc def"); editor.handleInput("\x17"); assert.equal(editor.getText(), "abc ");
	editor.handleInput("\x19"); assert.equal(editor.getText(), "abc def");
	editor.handleInput("\x01"); assert.equal(editor.getCursor().col, 0);
	editor.handleInput("\x05"); assert.equal(editor.getCursor().col, 7);
	editor.setText("line\\"); editor.handleInput("\r"); assert.equal(editor.getText(), "line\n");
	editor.setText("line"); editor.handleInput("\n"); assert.equal(editor.getText(), "line\n");
	editor.setText(""); editor.handleInput("\x1b[200~" + original.slice(0, 12)); editor.handleInput(original.slice(12) + "\x1b[201~tail");
	assert.equal(editor.getExpandedText(), original + "tail");
	editor.setText(""); editor.handleInput(`\x1b[200~${longPaste}\x1b[201~`);
	assert.ok(editor.getText().startsWith("[Paste #"));
	assert.equal(editor.getExpandedText().trim(), longPaste.trim());
	const saved = editor.getDraft();
	await handlers.get("session_shutdown")({ reason: "reload" }, ctx);
	assert.equal(mode.editor, defaultEditor);
	register(); await handlers.get("session_start")({}, ctx); editor = mode.editor;
	assert.deepEqual(editor.getDraft(), saved);
	editor.handleInput(`\x1b[200~${longPaste}second\x1b[201~`);
	assert.ok(editor.getExpandedText().includes("second"));
	editor.setText("/skill:trace-nim");
	const dark = editor.render(80).join("\n"); pi.initTheme("light");
	const light = editor.render(80).join("\n"); assert.notEqual(dark, light); assert.equal(plain(dark), plain(light));
	let requests = 0;
	const pending = [];
	editor.setAutocompleteProvider({
		triggerCharacters: ["%"],
		getSuggestions: (_lines, _line, _col, options) => {
			requests++;
			return new Promise(resolve => pending.push({ resolve, signal: options.signal }));
		},
		applyCompletion: () => { throw new Error("Unused completion"); },
	});
	editor.setText("");
	for (const char of "ordinary prompt without completion") editor.handleInput(char);
	await tick();
	assert.equal(requests, 0, "Plain typing must not query autocomplete");
	editor.setText("Check "); editor.handleInput("@s");
	assert.equal(requests, 1);
	pending.shift().resolve({ prefix: "@s", items: [{ value: "src", label: "src" }, { value: "setup", label: "setup" }] });
	await tick();
	assert.equal(editor.isShowingAutocomplete(), true);
	const menuHeight = editor.render(80).length;
	editor.handleInput("r");
	assert.equal(requests, 2);
	assert.equal(editor.isShowingAutocomplete(), true, "Pending refresh must keep the visible popup");
	assert.equal(editor.render(80).length, menuHeight, "Pending refresh must not shrink the editor");
	pending.shift().resolve({ prefix: "@sr", items: [{ value: "src", label: "src" }] });
	await tick();
	editor.handleInput(" ");
	await tick();
	assert.equal(requests, 2, "Space ending a completion must stop requests");
	assert.equal(editor.isShowingAutocomplete(), false);
	editor.setText("Check "); editor.handleInput("%x");
	assert.equal(requests, 3, "Provider trigger characters must still work");
	const obsolete = pending.shift();
	editor.handleInput(" ");
	assert.equal(obsolete.signal.aborted, true);
	obsolete.resolve({ prefix: "%x", items: [{ value: "obsolete", label: "obsolete" }] });
	await tick(); assert.equal(editor.isShowingAutocomplete(), false, "Stale results must not reopen the popup");
	editor.setText("read fi"); editor.handleInput("\t");
	assert.equal(requests, 4, "Explicit Tab must still query ordinary file tokens");
	pending.shift().resolve({ prefix: "fi", items: [{ value: "file", label: "file" }, { value: "fixture", label: "fixture" }] });
	await tick(); editor.handleInput("l");
	assert.equal(requests, 5, "Explicit file completion must keep updating within its token");
	pending.shift().resolve(null);
	await tick(); assert.equal(editor.isShowingAutocomplete(), false, "Empty results must dismiss the previous popup");
	editor.setText("/skill:trace-nim");
	unlinkSync(files.get("trace-nim"));
	editor.handleInput("\r"); assert.equal(editor.getExpandedText(), "/skill:trace-nim"); assert.equal(errors.at(-1).kind, "error");
	const broken = await handlers.get("input")({ text: original, source: "interactive" }, ctx);
	assert.equal(broken.action, "handled");
	assert.ok(errors.at(-1).text.includes("trace-nim"));
	const palette = () => themeModule.theme;
	for (let steps = 0; steps < 15; steps++) for (const text of ["foo bar", "can't stop", "foo-bar/baz.qux", "hello 🌙 world", "a\nline two", "é 👩🏽‍💻 foo"]) {
		for (const input of ["\x1bb", "\x1bf", "\x17", "\x1bd", "\x15", "\x0b", "\x01", "\x05", "\x1b[A", "\x1b[B", "\x1b[D", "\x7f"]) {
			const native = new pi.CustomEditor(fakeTui, editorTheme, keys);
			const atomic = new helper.SkillInputEditor(fakeTui, editorTheme, keys, () => new Set(), palette);
			native.setText(text); atomic.setText(text); native.render(80); atomic.render(80);
			for (let move = 0; move < steps; move++) { native.handleInput("\x1b[D"); atomic.handleInput("\x1b[D"); }
			native.handleInput(input); atomic.handleInput(input);
			assert.equal(atomic.getText(), native.getText(), JSON.stringify({ text, steps, input }));
			assert.deepEqual(atomic.getCursor(), native.getCursor(), JSON.stringify({ text, steps, input }));
		}
	}
} finally { rmSync(scratch, { recursive: true, force: true }); }
console.log("PASS: native Pi editor factory/callbacks; inline/multiple atoms; autocomplete/typing/paste; whole-chip Backspace/undo; wrap 1–120, cursor/mouse/theme; canonical submit + native skill blocks; history/kill/yank/app keys; plain typing skips autocomplete; pending popup stays stable, stale results discarded; provider triggers/explicit Tab preserved; reload preserves opaque paste; missing source blocks submission.");
