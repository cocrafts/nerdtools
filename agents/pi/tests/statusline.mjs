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
const extension = await loader.import(fileURLToPath(new URL("../extensions/cc-statusline.ts", import.meta.url)));
const { visibleWidth } = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
const handlers = {};
let footer;
let renders = 0;
let now = 0;
const originalNow = Object.getOwnPropertyDescriptor(performance, "now");
Object.defineProperty(performance, "now", { configurable: true, value: () => now });
const ctx = {
	cwd: "/Users/le/metascript/talks/solana-meetup",
	mode: "tui",
	getContextUsage: () => undefined,
	sessionManager: { getEntryCount: () => 0, getEntries: () => [], getSessionName: () => undefined },
	ui: { setFooter: factory => {
		if (factory) footer = factory({ requestRender: () => renders++ }, { fg: (_, text) => text },
			{ onBranchChange: () => () => {}, getGitBranch: () => undefined });
	} },
};
const message = (output = 0, stopReason = "stop") => ({ role: "assistant", usage: { output }, stopReason });
const lines = (width = 120) => footer.render(width).map(line => line.replace(/\x1b\[[0-9;]*m/g, ""));
const begin = () => handlers.message_start({ message: message() }, ctx);
const delta = (type = "text_delta") => handlers.message_update({ message: message(), assistantMessageEvent: { type, delta: "x" } }, ctx);
const end = (output, stopReason) => handlers.message_end({ message: message(output, stopReason) }, ctx);
try {
	extension.default({ on: (name, handler) => handlers[name] = handler, getThinkingLevel: () => "medium" });
	handlers.session_start({}, ctx);
	assert.equal(lines()[0].trim(), "solana-meetup");
	assert.ok(lines()[1].includes("↑0 ↓0 ·  — tok/s"));
	begin();
	now = 10_000;
	delta();
	now = 12_000;
	end(42);
	assert.ok(lines()[1].includes("↑0 ↓0 ·  21.0 tok/s"));
	assert.ok(renders > 0);
	for (const type of ["thinking_delta", "toolcall_delta"]) {
		begin();
		now += 10_000;
		delta(type);
		now += 1_000;
		end(30, type === "toolcall_delta" ? "toolUse" : "stop");
		assert.ok(lines()[1].includes(" 30.0 tok/s"));
	}
	handlers.message_start({ message: { role: "toolResult" } }, ctx);
	now += 60_000;
	handlers.message_end({ message: { role: "toolResult" } }, ctx);
	assert.ok(lines()[1].includes(" 30.0 tok/s"));
	for (const reason of ["error", "aborted"]) {
		begin();
		delta();
		now += 1_000;
		end(42, reason);
		assert.ok(lines()[1].includes(" — tok/s"));
	}
	begin();
	end(42);
	assert.ok(lines()[1].includes(" — tok/s"));
	begin();
	delta();
	end(42);
	assert.ok(lines()[1].includes(" — tok/s"));
	for (const width of [1, 2, 20, 60, 120]) {
		for (const line of footer.render(width)) assert.ok(visibleWidth(line) <= width);
	}
	handlers.session_shutdown();
	handlers.session_start({}, ctx);
	assert.ok(lines()[1].includes(" — tok/s"));
	console.log("PASS statusline: cwd, throughput, thinking/tool streams, tool wait, errors, missing timing, widths, session reset");
} finally {
	handlers.session_shutdown?.();
	if (originalNow) Object.defineProperty(performance, "now", originalNow);
	else delete performance.now;
}
