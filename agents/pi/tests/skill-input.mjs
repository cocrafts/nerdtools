import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
const jiti = createJiti(import.meta.url, { alias: {
	"@earendil-works/pi-coding-agent": agentPath,
	"@earendil-works/pi-tui": tuiPath,
} });
const helper = await jiti.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format/skill-input.ts"));
const pi = await import(pathToFileURL(agentPath).href);
const tui = await import(pathToFileURL(tuiPath).href);
const themeModule = await import(pathToFileURL(join(root, "dist/modes/interactive/theme/theme.js")).href);
const { KeybindingsManager } = await import(pathToFileURL(join(root, "dist/core/keybindings.js")).href);
const { InteractiveMode } = await import(pathToFileURL(join(root, "dist/modes/interactive/interactive-mode.js")).href);
const { AgentSession } = await import(pathToFileURL(join(root, "dist/core/agent-session.js")).href);
pi.initTheme("dark");
const editorTheme = { borderColor: text => text, selectList: Object.fromEntries(["selectedPrefix", "selectedText", "description", "scrollInfo", "noMatch"].map(key => [key, text => text])) };
const fakeTui = { terminal: { rows: 40 }, setFocus(editor) { editor.focused = true; }, requestRender() {} };
const keys = new KeybindingsManager({});
const defaultEditor = new pi.CustomEditor(fakeTui, editorTheme, keys, { embedWorkingStatus: true });
let submitted;
defaultEditor.onSubmit = text => submitted = text;
defaultEditor.onChange = () => {};
const clearAction = () => {};
defaultEditor.actionHandlers.set("app.clear", clearAction);
const mode = {
	defaultEditor, editor: defaultEditor, ui: fakeTui, keybindings: keys,
	editorContainer: new tui.Container(), disposeActiveSelector() {},
	autocompleteProvider: new tui.CombinedAutocompleteProvider([{ name: "skill:worktree-relaunch", description: "relaunch" }], process.cwd()),
};
const ctx = { mode: "tui", ui: {
	get theme() { return themeModule.theme; },
	getEditorText: () => mode.editor.getExpandedText(),
	setEditorText: text => mode.editor.setText(text),
	setEditorComponent: factory => InteractiveMode.prototype.setCustomEditorComponent.call(mode, factory),
} };
const handlers = new Map();
helper.registerSkillInput({
	getCommands: () => [{ source: "skill", name: "skill:worktree-relaunch" }, { source: "extension", name: "not-a-skill" }],
	on: (name, handler) => handlers.set(name, handler),
});
const command = "/skill:worktree-relaunch";
const label = " worktree-relaunch";
const plain = tui.stripTerminalSequences;
const longPaste = "preserve pasted draft\n".repeat(80);
defaultEditor.handleInput(`\x1b[200~${longPaste}\x1b[201~`);
assert.notEqual(defaultEditor.getText(), longPaste);
assert.equal(defaultEditor.getExpandedText(), longPaste);
await handlers.get("session_start")({}, ctx);
assert.equal(mode.editor.getExpandedText(), longPaste);
assert.equal(mode.editor.onSubmit, defaultEditor.onSubmit);
assert.equal(mode.editor.onChange, defaultEditor.onChange);
assert.equal(mode.editor.actionHandlers.get("app.clear"), clearAction);
const editor = mode.editor;
assert.equal(editor.embedWorkingStatus, defaultEditor.embedWorkingStatus);
editor.setText(command);
let lines = editor.render(80);
assert.ok(plain(lines[1]).includes(label));
assert.ok(!plain(lines[1]).includes("/skill:"));
assert.equal(editor.getText(), command);
assert.equal(editor.getExpandedText(), command);
assert.equal(tui.visibleWidth(lines[1].split(tui.CURSOR_MARKER)[0]), tui.visibleWidth(label));
editor.handleInput("\r");
assert.equal(submitted, command);
editor.setText(command + " continue 🌙");
lines = editor.render(80);
assert.ok(plain(lines[1]).includes(label + " continue 🌙"));
const event = { type: "click", button: "left", x: tui.visibleWidth(label + " ") + 3, y: 1, screenX: 0, screenY: 1, width: 80, height: 3, shift: false, alt: false, ctrl: false };
assert.equal(editor.handleMouse(event).handled, true);
assert.equal(editor.getCursor().col, command.length + 4);
assert.equal(editor.handleMouse({ ...event, x: 3 }).handled, true);
assert.equal(editor.getCursor().col, command.length);
assert.equal(editor.handleMouse({ ...event, type: "drag" }), undefined);
editor.handleInput("\x1b[H");
assert.ok(plain(editor.render(80)[1]).includes("/skill:worktree-relaunch"));
for (const width of [8, 20, 40, 80]) for (const padding of [0, 2]) {
	editor.setPaddingX(padding);
	editor.setText(command + " continue 🌙");
	for (const line of editor.render(width)) assert.ok(tui.visibleWidth(line) <= width);
}
editor.setPaddingX(2);
editor.setText(command + " continue");
editor.render(80);
editor.handleMouse({ ...event, x: tui.visibleWidth(label + " ") + 3 + 2 });
assert.equal(editor.getCursor().col, command.length + 4);
editor.setPaddingX(0);
editor.setText(command);
const dark = editor.render(80)[1];
pi.initTheme("light");
const light = editor.render(80)[1];
assert.notEqual(light, dark);
assert.equal(plain(light), plain(dark));
for (const text of ["/skill:missing", command + ".", command + "\ncontinue", "explain " + command]) {
	editor.setText(text);
	assert.ok(!plain(editor.render(80).join("\n")).includes(label));
}
editor.setText("/skill:work");
editor.handleInput("\t");
await new Promise(resolve => setTimeout(resolve, 40));
editor.handleInput("\t");
assert.equal(editor.getText().trim(), command);
assert.ok(plain(editor.render(80)[1]).includes(label));
editor.setAutocompleteProvider({ getSuggestions: async () => null, applyCompletion() { throw new Error("unused"); } });
editor.setText("");
editor.handleInput(`\x1b[200~${command}\x1b[201~`);
assert.equal(editor.getExpandedText(), command);
assert.ok(plain(editor.render(80)[1]).includes(label));
editor.handleInput("\x7f");
assert.equal(editor.getText(), command.slice(0, -1));
assert.ok(!plain(editor.render(80)[1]).includes(label));
const known = new Set(["worktree-relaunch"]);
assert.equal(helper.expandSkillChip(label + " continue", known), command + " continue");
assert.equal(helper.expandSkillChip(" missing", known), " missing");
assert.equal(helper.expandSkillChip("example: " + label, known), "example: " + label);
assert.deepEqual(await handlers.get("input")({ text: label + " continue" }, ctx), { action: "transform", text: command + " continue" });
assert.equal(await handlers.get("input")({ text: command }, ctx), undefined);
assert.equal(await handlers.get("input")({ text: label }, { mode: "rpc" }), undefined);
const scratch = mkdtempSync(join(tmpdir(), "pi-skill-input-"));
try {
	const filePath = join(scratch, "SKILL.md");
	writeFileSync(filePath, "---\nname: worktree-relaunch\ndescription: fixture\n---\n## Handoff\nKeep the card and handoff.\n");
	const resourceLoader = { getSkills: () => ({ skills: [{ name: "worktree-relaunch", filePath, baseDir: scratch }] }) };
	editor.setText(command + " continue");
	editor.render(80);
	editor.handleInput("\r");
	const expanded = AgentSession.prototype._expandSkillCommand.call({ resourceLoader }, submitted);
	const parsed = pi.parseSkillBlock(expanded);
	assert.equal(parsed.name, "worktree-relaunch");
	assert.ok(parsed.content.includes("Keep the card and handoff."));
	assert.ok(!parsed.content.includes("description: fixture"));
	assert.equal(parsed.userMessage, "continue");
} finally {
	rmSync(scratch, { recursive: true, force: true });
}
editor.setText("");
editor.handleInput(`\x1b[200~${longPaste}\x1b[201~`);
await handlers.get("session_shutdown")({ reason: "reload" }, ctx);
assert.equal(mode.editor, defaultEditor);
assert.equal(defaultEditor.getExpandedText(), longPaste);
await handlers.get("session_start")({}, ctx);
assert.equal(mode.editor.getExpandedText(), longPaste);
mode.editor.setText(command);
assert.ok(plain(mode.editor.render(80)[1]).includes(label));
console.log("PASS: actual Pi editor installation, input chip/cursor/mouse, native autocomplete/paste/submit/skill expansion, unchanged canonical text, clipboard label conversion, theme/narrow/wrapped fallbacks, reload preserves draft.");
