import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
const dir = resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/codex-reset-fireworks");
const extension = await jiti.import(join(dir, "index.ts"));
const fireworks = await jiti.import(join(dir, "fireworks.ts"));
const tui = await import(pathToFileURL(tuiPath).href);
const agent = await import(pathToFileURL(agentPath).href);
const themeModule = await import(pathToFileURL(join(root, "dist/modes/interactive/theme/theme.js")).href);
agent.initTheme("dark");
const theme = themeModule.theme;
const detect = fireworks.detectCodexResetFireworks;
const before = { observedAt: 1000, sevenDay: { percent: 80, resetsAt: 5000, plan: "pro" }, savedResets: 1 };
const after = { observedAt: 2000, sevenDay: { percent: 0, resetsAt: 9000, plan: "pro" }, savedResets: 1 };
assert.deepEqual(detect(before, after), { kind: "unscheduled-weekly-reset" });
assert.equal(detect(before, { ...after, observedAt: 5000 }), undefined);
assert.equal(detect(before, { ...after, observedAt: undefined }), undefined);
assert.equal(detect(before, { ...after, savedResets: 0 }), undefined);
assert.equal(detect(before, { ...after, savedResets: undefined }), undefined);
assert.equal(detect(before, { ...after, sevenDay: { ...after.sevenDay, resetsAt: 5000 } }), undefined);
assert.equal(detect(before, { ...after, sevenDay: { ...after.sevenDay, plan: "plus" } }), undefined);
assert.equal(detect(before, { ...after, sevenDay: { ...after.sevenDay, percent: 90 } }), undefined);
assert.equal(detect(before, { ...after, sevenDay: undefined }), undefined);
assert.equal(detect({ ...before, sevenDay: { ...before.sevenDay, percent: 0 } }, after), undefined);
assert.deepEqual(detect(before, { ...after, savedResets: 3 }), { kind: "saved-reset-banked", added: 2, available: 3 });

const report = (account, percent, reset, count = 1, observedAt = 2000) => ({
	account, observedAt,
	body: { plan_type: "pro", rate_limit: {
		primary_window: { used_percent: 20, reset_at: 4, limit_window_seconds: 18000 },
		secondary_window: { used_percent: percent, reset_at: reset, limit_window_seconds: 604800 },
	}, rate_limit_reset_credits: { available_count: count } },
});
assert.deepEqual(extension.quotaSnapshot(report("a", 0, 9)), after);
const reordered = report("a", 0, 9);
[reordered.body.rate_limit.primary_window, reordered.body.rate_limit.secondary_window] =
	[reordered.body.rate_limit.secondary_window, reordered.body.rate_limit.primary_window];
assert.deepEqual(extension.quotaSnapshot(reordered), after);
assert.equal(extension.quotaSnapshot({ account: "a", observedAt: 1, body: {} }).sevenDay, undefined);

for (const event of [{ kind: "unscheduled-weekly-reset" }, { kind: "saved-reset-banked", added: 2, available: 3 }]) {
	for (const width of [1, 2, 7, 8, 20, 62, 96, 200]) {
		for (const height of [1, 2, 3, 8, 24]) {
			for (let frame = 0; frame < 34; frame++) {
				const lines = fireworks.renderCodexResetFireworks(width, height, frame, event, theme);
				assert.equal(lines.length, height);
				for (const line of lines) assert.ok(tui.visibleWidth(line) <= width);
			}
		}
	}
}

const { createEventBus } = await import(pathToFileURL(join(root, "dist/core/event-bus.js")).href);
const events = createEventBus();
const handlers = {};
const commands = {};
const pi = { events, on: (name, handler) => handlers[name] = handler,
	registerCommand: (name, command) => commands[name] = command };
extension.default(pi);
let component;
let renders = 0;
let opened = 0;
let resolved = 0;
const errors = [];
const ctx = { mode: "tui", ui: {
	notify: (...args) => errors.push(args),
	custom: (factory, options) => {
		assert.deepEqual(options.overlayOptions, { anchor: "top-center", width: "100%", maxHeight: "33%", margin: 0 });
		opened++;
		return new Promise(resolve => {
			component = factory({ terminal: { rows: 30 }, requestRender: () => renders++ }, theme, {}, () => {
				component.dispose();
				resolved++;
				resolve();
			});
		});
	},
} };
const tick = () => new Promise(resolve => setImmediate(resolve));
handlers.session_start({}, ctx);
events.emit("codex-quota-report", report("a", 80, 5));
assert.equal(opened, 0);
events.emit("codex-quota-report", report("b", 0, 9));
assert.equal(opened, 0);
events.emit("codex-quota-report", report("b", 80, 9));
events.emit("codex-quota-report", report("b", 0, 15));
assert.equal(opened, 1);
component.handleInput("x");
await new Promise(resolve => setTimeout(resolve, 3100));
assert.ok(renders >= 34);
assert.equal(resolved, 0);
events.emit("codex-quota-report", report("b", 0, 15, 2));
assert.equal(opened, 1);
component.handleInput("\x1b");
await tick();
assert.equal(resolved, 1);
const stoppedRenders = renders;
await new Promise(resolve => setTimeout(resolve, 180));
assert.equal(renders, stoppedRenders);
events.emit("codex-quota-report", report("b", 0, 15, 3));
assert.equal(opened, 2);
assert.ok(component.render(80).join("\n").includes("New reset banked"));
handlers.session_shutdown();
await tick();
assert.equal(resolved, 2);
events.emit("codex-quota-report", report("b", 0, 15, 4));
assert.equal(opened, 2);
assert.equal(errors.length, 0);

handlers.session_start({}, ctx);
const demo = commands.fireworks.handler("", ctx);
assert.equal(opened, 3);
component.handleInput("\x1b");
await demo;
assert.equal(resolved, 3);
handlers.session_shutdown();
const temp = mkdtempSync(join(tmpdir(), "pi-quota-test-"));
const originalFetch = globalThis.fetch;
const originalNow = Date.now;
try {
	const credentialStub = join(temp, "credential.mjs");
	writeFileSync(credentialStub, 'export function readStoredCredential() { return { type: "oauth", accountId: "test", email: "test@example.com", access: "test-token" }; }');
	const footerLoader = createJiti(import.meta.url, { alias: {
		"@earendil-works/pi-coding-agent": credentialStub,
		"@earendil-works/pi-tui": tuiPath,
	} });
	const footerModule = await footerLoader.import(resolve(dir, "../cc-statusline.ts"));
	const footerHandlers = {};
	const realEvents = createEventBus();
	let footer;
	let fetches = 0;
	let overlay;
	let finished;
	let now = 1_000_000;
	Date.now = () => now;
	const realCtx = { mode: "tui", model: { provider: "openai-codex" }, ui: {
		notify: message => { throw new Error(message); },
		setFooter: factory => {
			if (factory) footer = factory({ requestRender() {} }, theme, { onBranchChange: () => () => {} });
		},
		custom: factory => new Promise(resolve => {
			finished = resolve;
			overlay = factory({ terminal: { rows: 30 }, requestRender() {} }, theme, {}, resolve);
		}),
	} };
	globalThis.fetch = async url => {
		assert.equal(url, "https://chatgpt.com/backend-api/wham/usage");
		const body = report("test", fetches++ === 0 ? 80 : 0, fetches === 1 ? 5000 : 9000).body;
		return { ok: true, json: async () => body };
	};
	const fireworksHandlers = {};
	extension.default({ events: realEvents, on: (name, fn) => fireworksHandlers[name] = fn, registerCommand() {} });
	fireworksHandlers.session_start({}, realCtx);
	footerModule.default({ events: realEvents, on: (name, fn) => footerHandlers[name] = fn });
	footerHandlers.session_start({}, realCtx);
	await tick();
	assert.equal(fetches, 1);
	assert.equal(overlay, undefined);
	now += 300_001;
	footerHandlers.agent_end({}, realCtx);
	await tick();
	assert.equal(fetches, 2);
	assert.ok(overlay.render(80).join("\n").includes("Weekly usage cleared early"));
	overlay.handleInput("\x1b");
	await tick();
	footerHandlers.session_shutdown();
	fireworksHandlers.session_shutdown();
	footer.dispose();
	finished();
} finally {
	globalThis.fetch = originalFetch;
	Date.now = originalNow;
	rmSync(temp, { recursive: true, force: true });
}
console.log("PASS: OMP detection, quota mapping, 2720 render frames, looping until Esc, single overlay, shutdown, preview and real statusline-to-overlay integration");
