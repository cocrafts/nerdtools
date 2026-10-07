import assert from "node:assert/strict";
import { mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
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
const extensionDir = resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format");
const extension = await jiti.import(join(extensionDir, "index.ts"));
const files = await jiti.import(join(extensionDir, "file-link.ts"));
const pi = await import(pathToFileURL(agentPath).href);
const tui = await import(pathToFileURL(tuiPath).href);
const theme = await import(pathToFileURL(join(root, "dist/modes/interactive/theme/theme.js")).href);
const cwd = realpathSync(mkdtempSync(join(tmpdir(), "pi-output-test-")));
const plain = value => value.replace(/\x1b\[[0-9;]*m/g, "");

try {
	writeFileSync(join(cwd, "hello.ms"), "let x = 1\n");
	symlinkSync(process.execPath, join(cwd, "outside"));
	assert.equal(files.resolveFileLink("outside", cwd), undefined);
	assert.equal(files.resolveFileLink("missing", cwd), undefined);
	assert.deepEqual(files.resolveFileLink("hello.ms:3:4", cwd), { path: join(cwd, "hello.ms"), line: 3, column: 4 });
	assert.equal(files.displayPath(join(cwd, "hello.ms"), cwd), "hello.ms");
	pi.initTheme("dark");
	let resolver;
	const lifecycle = new Map();
	extension.default({ registerToolRenderer: value => resolver = value, registerMarkdownTransformer() {}, on: (name, handler) => lifecycle.set(name, handler) });
	let opened = 0;
	await lifecycle.get("session_start")({}, { cwd, mode: "tui", isIdle: () => true, ui: {
		custom: async factory => { assert.equal(typeof factory, "function"); opened++; return { status: 0 }; },
		notify: message => { throw new Error(message); },
	} });
	const peersResult = { content: [{ type: "text", text: Array.from({ length: 15 }, (_, index) => `pi-${index} [${index}] interactive/idle vouched=true /worktree-${index}`).join("\n") }], details: {} };
	const peersBefore = JSON.stringify(peersResult);
	const peers = new pi.ToolExecutionComponent("cc_list_peers", "peers-test", {}, {}, resolver("cc_list_peers", () => undefined), { requestRender() {} }, cwd);
	peers.setArgsComplete();
	peers.updateResult(peersResult, false);
	let peersRows = peers.render(100);
	assert.ok(peersRows.some(line => line.includes("pi-0") && line.includes(theme.theme.getFgAnsi("dim"))));
	assert.ok(!plain(peersRows.join("\n")).includes("pi-14"));
	assert.ok(plain(peersRows.join("\n")).includes("10 more lines"));
	assert.ok(plain(peersRows.join("\n")).includes("cc_list_peers"));
	peers.setExpanded(true);
	peersRows = peers.render(100);
	assert.ok(peersRows.some(line => line.includes("pi-14") && line.includes(theme.theme.getFgAnsi("dim"))));
	assert.equal(JSON.stringify(peersResult), peersBefore);
	for (const width of [8, 40, 100]) for (const line of peers.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	peers.updateResult({ content: [{ type: "text", text: "peer discovery failed" }], details: {}, isError: true }, false);
	assert.ok(peers.render(100).some(line => line.includes("peer discovery failed") && line.includes(theme.theme.getFgAnsi("error"))));

	const read = pi.createReadToolDefinition(cwd);
	const specialized = { renderResult: () => new tui.Text("specialized") };
	assert.equal(resolver("other", () => specialized), specialized);
	const wrappedOutput = Array.from({ length: 12 }, (_, index) => `row-${index}: long wrapped output with 🌙 Unicode and more text`).join("\n");
	for (const width of [8, 40, 100]) {
		const complete = new tui.Text(theme.theme.fg("dim", wrappedOutput), 1, 0).render(width);
		const preview = new extension.OutputPreview(wrappedOutput, theme.theme, "dim", 1).render(width);
		assert.equal(preview.length, 6);
		assert.deepEqual(preview.slice(0, 5), complete.slice(0, 5));
		for (const line of preview) assert.ok(tui.visibleWidth(line) <= width);
	}
	const genericResult = { content: [{ type: "text", text: wrappedOutput }], details: {} };
	const genericBefore = JSON.stringify(genericResult);
	const genericRenderer = resolver("plain-tool", () => undefined);
	const generic = new pi.ToolExecutionComponent("plain-tool", "plain-test", {}, {}, genericRenderer, { requestRender() {} }, cwd);
	generic.updateResult(genericResult, false);
	assert.ok(!plain(generic.render(40).join("\n")).includes("row-11"));
	generic.setExpanded(true);
	assert.ok(plain(generic.render(100).join("\n")).includes("row-11"));
	assert.equal(JSON.stringify(genericResult), genericBefore);
	const previewOptions = { expanded: false, isPartial: false };
	const previewContext = { args: {}, isError: false };
	assert.equal(genericRenderer.renderResult(genericResult, previewOptions, theme.theme, previewContext).render(40).length, 6);
	assert.equal(resolver("bash", () => undefined).renderResult(genericResult, previewOptions, theme.theme, previewContext).render(40).length, 6);
	const args = { path: join(cwd, "hello.ms") };
	const ui = { requestRender() {} };
	const component = new pi.ToolExecutionComponent("read", "read-test", args, {}, resolver("read", () => read), ui, cwd);
	component.setArgsComplete();
	component.markExecutionStarted();
	component.updateResult(await read.execute("read-test", args, undefined, () => {}, { cwd }), false);
	for (const width of [1, 8, 40, 120]) {
		for (const line of component.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	}
	assert.ok(component.render(80).join("\n").includes("Read"));
	assert.ok(!component.render(80).join("\n").includes("let x = 1"));
	component.setExpanded(true);
	assert.ok(plain(component.render(80).join("\n")).includes("let x = 1"));
	const fileClick = { type: "click", button: "left", x: 9, y: 1, screenX: 9, screenY: 1, width: 80, height: 3, shift: false, alt: false, ctrl: false };
	assert.equal(component.handleMouse(fileClick).handled, true);
	await new Promise(resolve => setImmediate(resolve));
	assert.equal(opened, 1, "native tool mouse click must reach the editor hook");

	let clicked;
	const row = new extension.ToolCallLine("→ Read", "hello.ms", "", theme.theme, files.resolveFileLink("hello.ms", cwd), value => clicked = value);
	const container = new tui.Container();
	container.addChild(row);
	container.render(80);
	const event = { type: "click", button: "left", x: 8, y: 0, screenX: 8, screenY: 0, width: 80, height: 1, shift: false, alt: false, ctrl: false };
	assert.equal(container.handleMouse(event).handled, true);
	assert.equal(clicked.path, join(cwd, "hello.ms"));
	assert.equal(container.handleMouse({ ...event, x: 0 }), undefined);

	const edit = pi.createEditToolDefinition(cwd);
	const editArgs = { path: args.path, edits: [{ oldText: "let x = 1", newText: "let x = 2" }] };
	const edited = await edit.execute("edit-test", editArgs, undefined, () => {}, { cwd });
	const editComponent = new pi.ToolExecutionComponent("edit", "edit-test", editArgs, {}, resolver("edit", () => edit), ui, cwd);
	editComponent.updateResult(edited, false);
	assert.ok(editComponent.render(80).join("\n").includes("+1"));
	editComponent.setExpanded(true);
	assert.ok(plain(editComponent.render(80).join("\n")).includes("let x = 2"));
	for (const width of [1, 8, 40, 120]) {
		for (const line of editComponent.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	}
	component.updateResult({ content: [{ type: "text", text: "Error: denied" }], details: undefined, isError: true }, false);
	component.setExpanded(false);
	assert.ok(component.render(80).join("\n").includes("Error: denied"));
	const typescript = "const answer: number = 42;\n// a comment\n";
	writeFileSync(join(cwd, "hello.ts"), typescript);
	const tsArgs = { path: join(cwd, "hello.ts") };
	const tsResult = await read.execute("ts-test", tsArgs, undefined, () => {}, { cwd });
	const originalResult = JSON.stringify(tsResult);
	const tsComponent = new pi.ToolExecutionComponent("read", "ts-test", tsArgs, {}, resolver("read", () => read), ui, cwd);
	tsComponent.updateResult(tsResult, false);
	assert.ok(!tsComponent.render(80).join("\n").includes("const answer"));
	tsComponent.setExpanded(true);
	const highlighted = tsComponent.render(80).join("\n");
	assert.ok(highlighted.includes(theme.theme.fg("syntaxKeyword", "const")));
	assert.ok(highlighted.includes(theme.theme.fg("syntaxNumber", "42")));
	assert.ok(highlighted.includes(theme.theme.fg("syntaxComment", "// a comment")));
	assert.ok(highlighted.replace(/\x1b\[[0-9;]*m/g, "").includes("const answer: number = 42;"));
	assert.equal(JSON.stringify(tsResult), originalResult);
	for (const width of [1, 8, 40, 120]) {
		for (const line of tsComponent.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	}
	const msHighlight = await jiti.import(join(extensionDir, "metascript-highlight.ts"));
	const metascript = 'const message: string = "hi <&>";\nlet count: i32 = 42;\n// comment\nmacro greet() { return true; }\n';
	for (const suffix of ["ms", "msc", "cms"]) {
		writeFileSync(join(cwd, `colored.${suffix}`), metascript);
		const msArgs = { path: join(cwd, `colored.${suffix}`) };
		const msResult = await read.execute("ms-test", msArgs, undefined, () => {}, { cwd });
		const unchanged = JSON.stringify(msResult);
		const msComponent = new pi.ToolExecutionComponent("read", "ms-test", msArgs, {}, resolver("read", () => read), ui, cwd);
		msComponent.updateResult(msResult, false);
		assert.ok(!plain(msComponent.render(80).join("\n")).includes("const message"));
		msComponent.setExpanded(true);
		const colored = msComponent.render(120).join("\n");
		for (const [token, text] of [["syntaxKeyword", "const"], ["syntaxType", "i32"], ["syntaxNumber", "42"], ["syntaxString", '"hi <&>"'], ["syntaxComment", "// comment"], ["syntaxFunction", "greet"]]) {
			assert.ok(colored.includes(theme.theme.fg(token, text)), `MetaScript ${token}: ${text}`);
		}
		assert.ok(plain(colored).includes('const message: string = "hi <&>";'));
		assert.equal(JSON.stringify(msResult), unchanged);
		for (const width of [1, 8, 40, 120]) for (const line of msComponent.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	}
	for (const sample of ['', '/* multiline\ncomment */\nlet text = "own \\"string\\"";', "@target(\"c\")\nclass Widget { value: i32; }", "const raw = `<tag>&amp; ${name}`;\nconst quote = '\\'';", "let unicode = \"Việt Nam 界\";\n"]) {
		assert.equal(plain(msHighlight.highlightMetaScript(sample, theme.theme)), sample);
	}
	const saigon = theme.loadThemeFromPath(resolve(extensionDir, "../../themes/saigon-night.json"), "truecolor");
	assert.ok(msHighlight.highlightMetaScript('const answer = 42;', saigon).includes(saigon.fg("syntaxNumber", "42")));
	assert.notEqual(msHighlight.highlightMetaScript('const answer = 42;', saigon), msHighlight.highlightMetaScript('const answer = 42;', theme.theme));

	const bash = pi.createBashToolDefinition(cwd);
	const bashArgs = { command: 'if true; then printf "hello\\n"; fi' };
	const bashResult = await bash.execute("bash-test", bashArgs, undefined, () => {}, { cwd, sessionManager: { getSessionId: () => "neon-format-test", getSessionFile: () => undefined } });
	const bashUnchanged = JSON.stringify(bashResult);
	const bashComponent = new pi.ToolExecutionComponent("bash", "bash-test", bashArgs, {}, resolver("bash", () => bash), ui, cwd);
	bashComponent.updateResult(bashResult, false);
	const bashRendered = bashComponent.render(120).join("\n");
	assert.ok(bashRendered.includes(theme.theme.fg("syntaxKeyword", "if")));
	assert.ok(plain(bashRendered).includes(bashArgs.command));
	assert.ok(plain(bashRendered).includes("hello"));
	const dimHello = theme.theme.fg("dim", "hello").replace(/\x1b\[39m$/, "");
	assert.ok(bashRendered.includes(dimHello));
	bashComponent.setExpanded(true);
	assert.ok(bashComponent.render(120).join("\n").includes(dimHello));
	assert.equal(JSON.stringify(bashResult), bashUnchanged);
	for (const width of [1, 8, 40, 120]) for (const line of bashComponent.render(width)) assert.ok(tui.visibleWidth(line) <= width);
	const syntaxDiff = await jiti.import(join(extensionDir, "syntax-diff.ts"));
	const diffText = ' 1 /* comment\n 2 still comment */\n-3 const answer: i32 = 42;\n+3 const answer: i32 = 43;';
	for (const path of ["sample.ms", "sample.ts"]) {
		const view = new syntaxDiff.SyntaxDiff(diffText, path, theme.theme);
		const rendered = view.render(120).join("\n");
		assert.ok(rendered.includes(theme.theme.fg("syntaxKeyword", "const")));
		assert.ok(rendered.includes(theme.theme.fg("syntaxComment", "/* comment")));
		assert.ok(rendered.includes(theme.theme.fg("toolDiffRemoved", "-3 ")));
		assert.ok(rendered.includes(theme.theme.fg("toolDiffAdded", "+3 ")));
		assert.ok(plain(rendered).includes("-3 const answer: i32 = 42;"));
		assert.ok(plain(rendered).includes("+3 const answer: i32 = 43;"));
		const backgrounds = [...rendered.matchAll(/\x1b\[48;2;([0-9;]+)m/g)].map(match => match[1]);
		assert.ok(new Set(backgrounds).size >= 4, "distinct add/remove line and inline backgrounds");
		for (const width of [0, 1, 8, 40, 120]) for (const line of view.render(width)) assert.ok(tui.visibleWidth(line) <= width);
		view.invalidate();
		assert.equal(view.render(120).join("\n"), rendered);
		assert.notEqual(new syntaxDiff.SyntaxDiff(diffText, path, saigon).render(120).join("\n"), rendered);
	}
	for (const [before, after] of [['const s = "Việt Nam 界";', 'const s = "Việt Nam 文";'], ['const s = "e";', 'const s = "e\u0301";'], ['\tlet value = 1;', '\tlet value = 20;']]) {
		const rendered = new syntaxDiff.SyntaxDiff(`-1 ${before}\n+1 ${after}`, "sample.ms", theme.theme).render(120).join("\n");
		assert.ok(plain(rendered).includes(before.replaceAll("\t", "   ")));
		assert.ok(plain(rendered).includes(after.replaceAll("\t", "   ")));
	}
	const unchangedDiffResult = JSON.stringify(edited);
	editComponent.render(120);
	assert.equal(JSON.stringify(edited), unchangedDiffResult);
	console.log("PASS: read/edit/bash through Pi; TS/MS highlighting; syntax-colored diffs with line/inline backgrounds, multiline comments, Unicode, tabs, themes, narrow widths; dim Bash output; model content unchanged.");
} finally {
	rmSync(cwd, { recursive: true, force: true });
}
