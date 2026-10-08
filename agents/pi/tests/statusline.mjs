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
	"@earendil-works/pi-ai": join(root, "node_modules/@earendil-works/pi-ai/dist/index.js"),
	"@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
	"typebox/value": require.resolve("typebox/value"),
	"typebox": require.resolve("typebox"),
} });
const extension = await loader.import(fileURLToPath(new URL("../extensions/cc-statusline.ts", import.meta.url)));
const { visibleWidth } = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
const { createEventBus } = await loader.import(join(root, "dist/index.js"));
const handlers = {};
let footer;
let renders = 0;
let now = 0;
let entries = [];
let branch = [];
let gitBranch;
let sessionName;
const originalNow = Object.getOwnPropertyDescriptor(performance, "now");
Object.defineProperty(performance, "now", { configurable: true, value: () => now });
const ctx = {
	cwd: "/Users/le/metascript/talks/solana-meetup",
	mode: "tui",
	getContextUsage: () => undefined,
	sessionManager: {
		getEntryCount: () => entries.length,
		getEntries: () => entries,
		getBranch: () => branch,
		getLeafId: () => branch.at(-1)?.id ?? null,
		getSessionName: () => sessionName,
		getSessionId: () => "statusline-test",
	},
	ui: { setFooter: factory => {
		if (factory) footer = factory({ requestRender: () => renders++ }, { fg: (color, text) => color === "toolDiffAdded" ? `\x1b[32m${text}\x1b[39m` : text },
			{ onBranchChange: () => () => {}, getGitBranch: () => gitBranch });
	} },
};
const message = (output = 0, stopReason = "stop") => ({ role: "assistant", usage: { output }, stopReason });
const lines = (width = 120) => footer.render(width).map(line => line.replace(/\x1b\[[0-9;]*m/g, ""));
const begin = () => handlers.message_start({ message: message() }, ctx);
const delta = (type = "text_delta") => handlers.message_update({ message: message(), assistantMessageEvent: { type, delta: "x" } }, ctx);
const end = (output, stopReason) => handlers.message_end({ message: message(output, stopReason) }, ctx);
try {
	extension.default({ events: createEventBus(), on: (name, handler) => handlers[name] = handler, getThinkingLevel: () => "medium" });
	handlers.session_start({}, ctx);
	assert.equal(lines()[0].trim(), "solana-meetup");
	gitBranch = "main";
	assert.equal(lines()[0].trim(), "solana-meetup");
	assert.ok(!lines()[1].includes("main"));
	gitBranch = "wt/skill-input";
	assert.equal(lines()[0].trim(), gitBranch);
	assert.ok(footer.render(120)[0].includes(`\x1b[32m${gitBranch}\x1b[39m`), "Feature branch must be green on row one");
	assert.ok(!lines()[1].includes(gitBranch), "Branch must not appear again on row two");
	for (const width of [0, 1, 2, 8, 20, 60]) for (const line of footer.render(width)) assert.ok(visibleWidth(line) <= width);
	gitBranch = undefined;
	assert.equal(lines()[0].trim(), "solana-meetup");
	assert.ok(lines()[1].includes(" —"));
	assert.ok(!/[↑↓]/.test(lines().join("\n")));
	ctx.getContextUsage = () => ({ tokens: 112_700, percent: 41 });
	assert.ok(lines()[0].includes("112.7K (41%)"));
	ctx.getContextUsage = () => undefined;
	assert.ok(lines()[1].includes(" — tok/s"));
	begin();
	now = 10_000;
	delta();
	now = 12_000;
	end(42);
	assert.ok(lines()[1].includes(" 21.0 tok/s"));
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
	begin();
	delta();
	now += 2_000;
	end(115);
	assert.ok(lines()[1].includes(" 57.5 tok/s"));
	begin();
	delta();
	now += 5_000;
	end(649);
	assert.ok(lines()[1].includes(" 129.8 tok/s"));
	for (const reason of ["error", "aborted"]) {
		begin();
		delta();
		now += 1_000;
		end(42, reason);
		assert.ok(lines()[1].includes(" —"));
	}
	begin();
	end(42);
	assert.ok(lines()[1].includes(" —"));
	begin();
	delta();
	end(42);
	assert.ok(lines()[1].includes(" —"));
	for (const width of [1, 2, 20, 60, 120]) {
		for (const line of footer.render(width)) assert.ok(visibleWidth(line) <= width);
	}
	handlers.session_shutdown();
	handlers.session_start({}, ctx);
	assert.ok(lines()[1].includes(" —"));
	const todoPlugin = await loader.import(fileURLToPath(new URL("../packages/rpiv-todo/todo.ts", import.meta.url)));
	let todoTool;
	todoPlugin.registerTodoTool({ registerTool: tool => todoTool = tool });
	const todo = async params => {
		const result = await todoTool.execute("test", params, undefined, undefined, ctx);
		const entry = { id: String(entries.length + 1), type: "message", message: { role: "toolResult", toolName: "todo", ...result } };
		handlers.message_end({ message: entry.message }, ctx);
		entries.push(entry);
		branch = [...branch, entry];
		const before = renders;
		handlers.turn_end({}, ctx);
		assert.ok(renders > before, "turn end must refresh persisted todo snapshot");
	};
	assert.ok(!/\(\d+\/\d+\)/.test(lines()[1]));
	await todo({ action: "create", subject: "First" });
	assert.ok(lines()[1].trimEnd().endsWith("(0/1)"));
	assert.ok(!lines()[1].includes("TODO"));
	await todo({ action: "update", id: 1, status: "in_progress" });
	await todo({ action: "update", id: 1, status: "completed" });
	await todo({ action: "create", subject: "Second" });
	await todo({ action: "create", subject: "Deleted" });
	await todo({ action: "delete", id: 3 });
	await todo({ action: "list", status: "pending" });
	sessionName = "Tên session 長い名前";
	assert.ok(lines()[1].trimEnd().endsWith(`${sessionName} · (1/2)`));
	for (const width of [0, 1, 2, 8, 20, 60, 120]) {
		for (const line of footer.render(width)) assert.ok(visibleWidth(line) <= width);
	}
	const shortName = sessionName;
	sessionName = "Session ".repeat(100);
	assert.ok(lines(60)[1].trimEnd().endsWith("(1/2)"), "long session name must not hide todo count");
	sessionName = shortName;
	const savedBranch = branch;
	await todo({ action: "clear" });
	assert.ok(!/\(\d+\/\d+\)/.test(lines()[1]));
	assert.ok(lines()[1].trimEnd().endsWith(sessionName));
	branch = savedBranch;
	handlers.session_tree({}, ctx);
	assert.ok(lines()[1].trimEnd().endsWith("(1/2)"), "branch switch restores todos despite unchanged entry count");
	handlers.session_shutdown();
	handlers.session_start({}, ctx);
	assert.ok(lines()[1].trimEnd().endsWith("(1/2)"), "session resume restores todos");
	branch = [];
	handlers.session_tree({}, ctx);
	assert.ok(!/\(\d+\/\d+\)/.test(lines()[1]), "abandoned branch todos stay hidden");
	sessionName = undefined;
	for (const hit of [undefined, 99, 98.01, 98, 95, 94]) {
		const cacheRead = hit === undefined ? 0 : hit * 100;
		entries.push({ type: "message", message: { role: "assistant", usage: {
			input: hit === undefined ? 0 : 10_000 - cacheRead,
			output: 0, cacheRead, cacheWrite: 0,
		} } });
		const line = lines()[1].trimEnd();
		assert.ok(!/[↑↓]/.test(line), "cumulative usage stays hidden even with recorded input/output");
		if (hit === undefined || hit > 98) {
			assert.ok(!line.includes(""), "gray cache indicator stays hidden");
			assert.ok(line.endsWith(" — tok/s"), "hidden cache leaves no separator");
		} else {
			assert.ok(line.endsWith(` ·  ${hit.toFixed(2)}%`), "warning/error cache stays visible");
		}
	}
	console.log("PASS statusline: throughput, widths, reset, todo counts, branch switch, resume, gray cache hidden, warning/error cache visible at boundaries");
} finally {
	handlers.session_shutdown?.();
	if (originalNow) Object.defineProperty(performance, "now", originalNow);
	else delete performance.now;
}
