import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
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
const helper = await jiti.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/cc-compat/context-message.ts"));
const pi = await import(pathToFileURL(agentPath).href);
const tui = await import(pathToFileURL(tuiPath).href);
pi.initTheme("dark");
let renderer;
helper.registerContextMessage({ registerMessageRenderer: (type, value) => {
	assert.equal(type, "claude-context");
	renderer = value;
} });
const content = "Worktree/card state:\n\nCard of this worktree, /workspace/.wt/root-sweep.md:\n# root-sweep\n\n## State\n\nResume this step.\n";
const message = { role: "custom", customType: "claude-context", content, display: true };
const original = JSON.stringify(message);
const component = new pi.CustomMessageComponent(message, renderer);
const plain = value => tui.stripTerminalSequences(value);
assert.equal(plain(component.render(80).join("\n")).trim(), "▸ root-sweep.md");
const event = { type: "click", button: "left", x: 3, y: 1, screenX: 3, screenY: 1, width: 80, height: 2, shift: false, alt: false, ctrl: false };
assert.equal(component.handleMouse(event).handled, true);
assert.ok(plain(component.render(80).join("\n")).includes("Resume this step."));
component.invalidate();
assert.ok(plain(component.render(80).join("\n")).includes("Resume this step."));
assert.equal(component.handleMouse(event).handled, true);
assert.equal(plain(component.render(80).join("\n")).trim(), "▸ root-sweep.md");
component.setExpanded(true);
assert.ok(plain(component.render(80).join("\n")).includes("Resume this step."));
component.setExpanded(false);
assert.equal(plain(component.render(80).join("\n")).trim(), "▸ root-sweep.md");
for (const width of [20, 40, 120]) {
	component.setExpanded(true);
	for (const line of component.render(width)) assert.ok(tui.visibleWidth(line) <= width);
}
assert.deepEqual(helper.contextFileNames(content + "Handoff from the previous session, /workspace/.wt/handoff/root-sweep.md, written today.\n"), ["root-sweep.md", "handoff/root-sweep.md"]);
assert.deepEqual(helper.contextFileNames("BOARD /workspace/.coach/workspace.md — yours\nHANDOFF /workspace/.coach/reentry.md — previous coach\n"), ["workspace.md", "reentry.md"]);
assert.equal(JSON.stringify(message), original);
const { loadExtensions } = await import(pathToFileURL(join(root, "dist/core/extensions/loader.js")).href);
const temp = mkdtempSync(join(tmpdir(), "pi-context-symlink-"));
try {
	const extensions = resolve(dirname(fileURLToPath(import.meta.url)), "../extensions");
	symlinkSync(extensions, join(temp, "extensions"), "dir");
	const loaded = await loadExtensions([join(temp, "extensions/cc-compat.ts")], process.cwd());
	assert.deepEqual(loaded.errors, []);
	assert.equal(loaded.extensions.length, 1);
	assert.ok(loaded.extensions[0].messageRenderers.has("claude-context"));
	const fixture = join(temp, "fixture");
	mkdirSync(fixture);
	execFileSync("git", ["init", "--quiet", "--initial-branch=wt/probe", fixture]);
	mkdirSync(join(fixture, ".cards"));
	writeFileSync(join(fixture, ".cards/probe.md"), "# probe\n\n## State\nVisible before the first prompt.\n");
	const delivery = Object.create(pi.AgentSession.prototype);
	delivery._isAgentRunActive = false;
	delivery._pendingNextTurnMessages = [];
	const delivered = [];
	delivery._appendCustomMessage = message => delivered.push(message);
	delivery._runAgentPrompt = () => { throw new Error("Startup context must not trigger the model"); };
	loaded.runtime.sendMessage = (message, options) => {
		assert.equal(options.triggerTurn, false);
		void delivery.sendCustomMessage(message, options);
	};
	const startup = loaded.extensions[0].handlers.get("session_start")[0];
	await startup({ reason: "startup" }, { cwd: fixture, sessionManager: { getSessionId: () => "context-startup-test" } });
	assert.equal(delivered.length, 1, "context must append before the first user prompt");
	assert.equal(delivery._pendingNextTurnMessages.length, 0);
	assert.equal(delivered[0].display, true);
	assert.ok(delivered[0].content.includes("Visible before the first prompt."));
	const liveRenderer = loaded.extensions[0].messageRenderers.get("claude-context");
	const startupComponent = new pi.CustomMessageComponent(delivered[0], liveRenderer);
	assert.equal(plain(startupComponent.render(80).join("\n")).trim(), "▸ probe.md");
	writeFileSync(join(fixture, ".cards/probe.md"), "# probe\n\n## State\nChanged card must not be reinjected by reload.\n");
	for (let reload = 0; reload < 3; reload++) await startup({ reason: "reload" }, { cwd: fixture, sessionManager: { getSessionId: () => "context-startup-test" } });
	assert.equal(delivered.length, 1, "Reload must not inject context, even if the card changed");
	for (const reason of ["new", "resume", "fork"]) await startup({ reason }, { cwd: fixture, sessionManager: { getSessionId: () => `context-${reason}-test` } });
	assert.equal(delivered.length, 4, "New/resume/fork still receive worktree context");
} finally {
	rmSync(temp, { recursive: true, force: true });
}
console.log("PASS: Pi loader through symlink; real startup → AgentSession appends before first prompt without triggering model; filename default, click/keyboard expansion, redraw, widths; content unchanged.");
