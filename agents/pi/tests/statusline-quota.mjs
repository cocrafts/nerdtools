import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const temp = mkdtempSync(join(tmpdir(), "pi-statusline-quota-"));
const originalFetch = globalThis.fetch;
const originalNow = Date.now;
const originalEnv = { HOME: process.env.HOME, PATH: process.env.PATH };
const handlers = {};
try {
	mkdirSync(join(temp, ".codex"));
	writeFileSync(join(temp, ".codex", "auth.json"), JSON.stringify({ tokens: { access_token: "cli-token", account_id: "cli-account" } }));
	mkdirSync(join(temp, "bin"));
	writeFileSync(join(temp, "bin", "codex"), `#!/bin/bash
[ "$1" = app-server ] || exit 2
while read -r line; do case $line in
*'"id":1'*) echo '{"id":1,"result":{}}' ;;
*'"id":2'*) echo '{"id":2,"result":{"rateLimits":{"planType":"pro","primary":{"usedPercent":77,"windowDurationMins":10080,"resetsAt":9999999999},"secondary":null}}}' ;;
esac; done
`);
	chmodSync(join(temp, "bin", "codex"), 0o755);
	process.env.HOME = temp;
	process.env.PATH = `${join(temp, "bin")}:${process.env.PATH}`;
	let now = originalNow();
	Date.now = () => now;

	const stub = join(temp, "credentials.mjs");
	writeFileSync(stub, `export function readStoredCredential(provider) {
		return provider === "openai"
			? { type: "oauth", clientId: "new-client", access: "new-token" }
			: { type: "oauth", accountId: "legacy-account", access: "old-token", email: "test@example.com" };
	}`);
	const loader = createJiti(import.meta.url, { alias: {
		"@earendil-works/pi-coding-agent": stub,
		"@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
	} });
	const { default: extension } = await loader.import(fileURLToPath(new URL("../extensions/cc-statusline.ts", import.meta.url)));
	let footer;
	const requests = [];
	let answer;
	globalThis.fetch = (url, options) => {
		assert.equal(url, "https://chatgpt.com/backend-api/wham/usage");
		requests.push({ headers: options.headers, signal: options.signal });
		return new Promise(resolve => { answer = resolve; });
	};
	const notes = [];
	const ctx = {
		cwd: "/test", mode: "tui", model: { provider: "openai" },
		getContextUsage: () => undefined,
		sessionManager: { getEntryCount: () => 0, getEntries: () => [], getSessionName: () => undefined },
		ui: {
			notify: message => notes.push(message),
			setFooter: factory => {
				if (factory) footer = factory({ requestRender() {} }, { fg: (_, text) => text }, {
					onBranchChange: () => () => {}, getGitBranch: () => undefined,
				});
			},
		},
	};
	const reports = [];
	extension({ on: (name, fn) => handlers[name] = fn, getThinkingLevel: () => "medium",
		events: { emit: (_, report) => reports.push(report) } });
	const row = () => footer.render(160)[0].replace(/\x1b\[[0-9;]*m/g, "");
	const until = async (done, what) => {
		for (let i = 0; i < 200 && !done(); i++) await new Promise(resolve => setTimeout(resolve, 10));
		assert.ok(done(), `timed out waiting for ${what}; row: ${row()}`);
	};
	const window = percent => ({ ok: true, status: 200, json: async () => ({ rate_limit: {
		primary_window: { used_percent: percent, reset_at: now / 1000 + 3600, limit_window_seconds: 604800 },
	} }) });

	handlers.session_start({}, ctx);
	assert.equal(requests.length, 1);
	assert.deepEqual(requests[0].headers, {
		Authorization: "Bearer cli-token", "ChatGPT-Account-Id": "cli-account",
		"User-Agent": "codex-cli", "OpenAI-Beta": "codex-1", originator: "Codex Desktop",
	});
	answer({ ok: false, status: 401 });
	await until(() => /77%/.test(row()), "the app-server fallback after a refused token");

	now += 30_000;
	handlers.model_select({}, ctx);
	assert.equal(requests.length, 1, "a refetch inside the minute");
	now += 30_000;
	handlers.model_select({}, ctx);
	assert.equal(requests.length, 2, "no refetch after a minute");
	answer({ ok: false, status: 500 });
	await until(() => /quota unavailable/.test(row()), "the failed read");
	assert.equal(notes.length, 1);
	now += 60_000;
	handlers.model_select({}, ctx);
	assert.equal(requests.length, 2, "a refetch a minute after a failure");
	now += 4 * 60_000;
	handlers.model_select({}, ctx);
	assert.equal(requests.length, 3, "no refetch five minutes after a failure");
	answer(window(61));
	await until(() => /61%/.test(row()), "the recovered read");

	ctx.model = { provider: "openai-codex" };
	handlers.model_select({}, ctx);
	assert.equal(requests.length, 4);
	assert.deepEqual(requests[3].headers, { Authorization: "Bearer old-token", "ChatGPT-Account-Id": "legacy-account" });
	answer(window(42));
	await until(() => /42%/.test(row()), "the openai-codex read");
	ctx.model = { provider: "openai" };
	handlers.model_select({}, ctx);
	assert.doesNotMatch(row(), /42%/);
	ctx.model = { provider: "openai-codex" };
	handlers.model_select({}, ctx);
	assert.equal(requests[4].signal.aborted, true, "the openai request outlives the switch");

	ctx.model = { provider: "anthropic" };
	handlers.model_select({}, ctx);
	assert.doesNotMatch(row(), /quota|%/);
	console.log("PASS statusline quota: Codex CLI token for the OpenAI sign-in, app-server fallback on 401, one-minute polling, five minutes after a failure, legacy headers, provider switching");
} finally {
	handlers.session_shutdown?.();
	globalThis.fetch = originalFetch;
	Date.now = originalNow;
	process.env.HOME = originalEnv.HOME;
	process.env.PATH = originalEnv.PATH;
	rmSync(temp, { recursive: true, force: true });
}
