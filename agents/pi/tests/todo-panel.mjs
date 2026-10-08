import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
	"@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
	"@earendil-works/pi-ai": join(root, "node_modules/@earendil-works/pi-ai/dist/index.js"),
	"@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
	"typebox/value": require.resolve("typebox/value"),
	"typebox": require.resolve("typebox"),
} });
const here = dirname(fileURLToPath(import.meta.url));
const pluginDir = resolve(here, "../packages/rpiv-todo");
const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")));
const loaded = await loadExtensions([join(pluginDir, "index.ts")], here);
assert.deepEqual(loaded.errors, []);
assert.equal(loaded.extensions.length, 1);
assert.ok(loaded.extensions[0].tools.has("todo"));
assert.ok(loaded.extensions[0].commands.has("todo-panel"));
const plugin = await loader.import(join(pluginDir, "index.ts"));
const footerExtension = await loader.import(resolve(here, "../extensions/cc-statusline.ts"));
const { createEventBus, initTheme } = await loader.import(join(root, "dist/index.js"));
const { Container, TuiAltScreen, visibleWidth } = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
const { dispatchMouseEvent } = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/tui.js"));
initTheme("dark");
const { theme } = await loader.import(join(root, "dist/modes/interactive/theme/theme.js"));
const events = createEventBus();
const pluginHandlers = {};
const footerHandlers = {};
const commands = {};
const tools = {};
const entries = [];
let branch = [];
let footer;
let renderRequests = 0;
const widgets = new Container();
const tui = { requestRender: () => renderRequests++ };
const ctx = {
	cwd: "/tmp/todo-panel-test",
	mode: "tui",
	hasUI: true,
	getContextUsage: () => undefined,
	sessionManager: {
		getSessionId: () => "foreground",
		getLeafId: () => branch.at(-1)?.id ?? null,
		getBranch: () => branch,
		getEntries: () => entries,
		getEntryCount: () => entries.length,
		getSessionName: () => "Session 長い名前",
	},
	ui: {
		theme,
		getToolsExpanded: () => false,
		notify: text => { throw new Error(text); },
		setWidget: (key, factory) => {
			assert.equal(key, "rpiv-todos");
			widgets.clear();
			if (factory) widgets.addChild(factory(tui, theme));
			tui.requestRender();
		},
		setFooter: factory => {
			if (factory) footer = factory(tui, theme, { onBranchChange: () => () => {}, getGitBranch: () => undefined });
		},
	},
};
plugin.default({
	events,
	on: (name, handler) => pluginHandlers[name] = handler,
	registerTool: tool => tools[tool.name] = tool,
	registerCommand: (name, command) => commands[name] = command,
	registerShortcut() {},
});
footerExtension.default({ events, on: (name, handler) => footerHandlers[name] = handler, getThinkingLevel: () => "medium" });
const strip = line => line.replace(/\x1b\[[0-9;]*m/g, "");
const settle = () => new Promise(resolve => setImmediate(resolve));
const page = new Container();
page.addChild(widgets);
const render = (width = 120) => page.render(width).map(strip);
const assertCounterColor = (label, visible, width = 120) => {
	assert.ok(footer.render(width)[1].includes(theme.fg(visible ? "toolDiffAdded" : "dim", label)),
		`counter ${label} must be ${visible ? "green" : "dim"}`);
};
const todo = async params => {
	const result = await tools.todo.execute("test", params, undefined, undefined, ctx);
	await pluginHandlers.tool_execution_end({ toolName: "todo", isError: false }, ctx);
	const entry = { id: String(entries.length + 1), type: "message", message: { role: "toolResult", toolName: "todo", ...result } };
	entries.push(entry);
	branch = [...branch, entry];
	footerHandlers.turn_end({}, ctx);
};
const mouse = (x, y, type = "click", button = "left", width = 120) => dispatchMouseEvent(page, {
	type, button, x, y, screenX: x, screenY: y, width, height: render(width).length,
	shift: false, alt: false, ctrl: false,
});
const clickCounter = async (width = 120) => {
	const lines = render(width);
	const y = lines.length - 1;
	const match = /\(\d+\/\d+\)/.exec(lines[y]);
	assert.ok(match);
	const x = visibleWidth(lines[y].slice(0, match.index));
	const before = renderRequests;
	assert.equal(mouse(x, y, "press", "left", width)?.handled, true);
	assert.equal(mouse(x, y, "click", "left", width)?.handled, true);
	await settle();
	assert.ok(renderRequests > before);
	assertCounterColor(match[0], widgets.render(width).length > 0, width);
};
try {
	await pluginHandlers.session_start({}, ctx);
	footerHandlers.session_start({}, ctx);
	page.addChild(footer);
	await todo({ action: "create", subject: "First" });
	await todo({ action: "create", subject: "Second" });
	assert.ok(widgets.render(120).map(strip).join("\n").includes("Todos (0/2)"));
	assertCounterColor("(0/2)", true);
	page.removeChild(footer);
	footerHandlers.session_start({}, ctx);
	page.addChild(footer);
	assertCounterColor("(0/2)", true);
	await clickCounter();
	assert.deepEqual(widgets.render(120), [], "hide entire panel including heading and spacer");
	assert.ok(render().at(-1).trimEnd().endsWith("(0/2)"));
	await todo({ action: "create", subject: "Third while hidden" });
	await todo({ action: "update", id: 1, status: "in_progress" });
	await todo({ action: "update", id: 1, status: "completed" });
	assert.deepEqual(widgets.render(120), [], "mutations must not reopen hidden panel");
	assert.ok(render().at(-1).trimEnd().endsWith("(1/3)"));
	assertCounterColor("(1/3)", false);
	await clickCounter(60);
	assert.ok(widgets.render(60).map(strip).join("\n").includes("Todos (1/3)"));
	assert.ok(widgets.render(60).map(strip).join("\n").includes("Third while hidden"));
	for (const [x, y, button] of [[0, render().length - 1, "left"], [112, render().length - 2, "left"], [114, render().length - 1, "right"]]) {
		assert.equal(mouse(x, y, "click", button), undefined);
	}
	events.emit("rpiv-todo-toggle-panel", { sessionId: "child" });
	await settle();
	assert.ok(widgets.render(120).length > 0, "child must not toggle foreground panel");
	events.emit("rpiv-todo-panel-visibility", { sessionId: "child", visible: false });
	assertCounterColor("(1/3)", true);
	await commands["todo-panel"].handler("", ctx);
	assert.deepEqual(widgets.render(120), []);
	assertCounterColor("(1/3)", false);
	await pluginHandlers.session_tree({}, ctx);
	assert.deepEqual(widgets.render(120), [], "branch replay must keep visibility choice");
	await commands["todo-panel"].handler("", ctx);
	assert.ok(widgets.render(120).length > 0);
	assertCounterColor("(1/3)", true);
	await clickCounter();
	await todo({ action: "clear" });
	assert.deepEqual(widgets.render(120), []);
	assert.ok(!/\(\d+\/\d+\)/.test(render().at(-1)));
	await todo({ action: "create", subject: "After clear" });
	assert.deepEqual(widgets.render(120), []);
	await clickCounter();
	assert.ok(widgets.render(120).length > 0);
	for (const width of [0, 1, 2, 20, 60, 120]) {
		for (const line of page.render(width)) assert.ok(visibleWidth(line) <= width);
	}
	await todo({ action: "update", id: 1, status: "in_progress" });
	await todo({ action: "update", id: 1, status: "completed" });
	render();
	await pluginHandlers.agent_start({}, ctx);
	assert.deepEqual(widgets.render(120), [], "plugin auto-hides previously displayed completed tasks");
	assertCounterColor("(1/1)", false);
	await clickCounter();
	assert.ok(widgets.render(120).map(strip).join("\n").includes("Todos (1/1)"), "click must reopen even an auto-hidden completed panel");
	let terminalInput;
	const screen = new TuiAltScreen({
		columns: 120, rows: 30, kittyProtocolActive: false,
		start: input => terminalInput = input,
		stop() {}, write() {}, hideCursor() {}, showCursor() {},
	});
	try {
		screen.setLayoutRoot(page);
		screen.start();
		for (const hidden of [true, false]) {
			screen.doRender();
			const frame = screen.getScreenLines().map(strip);
			const y = frame.findLastIndex(line => /\(\d+\/\d+\)/.test(line));
			const match = /\(\d+\/\d+\)/.exec(frame[y]);
			assert.ok(match);
			const x = visibleWidth(frame[y].slice(0, match.index));
			terminalInput(`\x1b[<0;${x + 1};${y + 1}M`);
			terminalInput(`\x1b[<0;${x + 1};${y + 1}m`);
			await settle();
			assert.equal(widgets.render(120).length === 0, hidden, "raw SGR mouse press/release must toggle exactly once");
			assertCounterColor("(1/1)", !hidden);
		}
	} finally {
		screen.stop();
	}
	await pluginHandlers.session_shutdown({}, ctx);
	assert.deepEqual(widgets.render(120), []);
	const beforeShutdownClick = renderRequests;
	events.emit("rpiv-todo-toggle-panel", { sessionId: "foreground" });
	await settle();
	assert.equal(renderRequests, beforeShutdownClick, "shutdown removes toggle listener");
	await pluginHandlers.session_start({}, ctx);
	assert.ok(widgets.render(120).length > 0, "new session starts visible");
	await clickCounter();
	assert.deepEqual(widgets.render(120), []);
	console.log("PASS todo panel: native Pi loader, real plugin + footer, fullscreen SGR mouse input, hide/show, live hidden updates, keyboard, branch replay, child isolation, clear, widths, reload, listener cleanup");
} finally {
	await pluginHandlers.session_shutdown({}, ctx);
	footerHandlers.session_shutdown();
}
