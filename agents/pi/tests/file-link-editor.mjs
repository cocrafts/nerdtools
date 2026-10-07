import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const jiti = createJiti(import.meta.url);
const { onFileLink } = await jiti.import(resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format/on-file-link.ts"));
const cwd = realpathSync(mkdtempSync(join(tmpdir(), "pi-editor-test-")));
try {
	const path = join(cwd, "a file 'with quotes'.txt");
	writeFileSync(path, "alpha\nbravo\ncharlie\n");
	const link = { path, line: 2, column: 3 };
	const events = [];
	const tui = { stop: () => events.push("stop"), start: () => events.push("start"), requestRender: force => { assert.equal(force, true); events.push("render"); } };
	const ctx = {
		cwd, mode: "tui", isIdle: () => true,
		ui: { custom: factory => new Promise(resolve => factory(tui, undefined, undefined, value => { events.push("done"); resolve(value); })) },
	};
	const run = (command, args, options) => {
		events.push("nvim");
		assert.equal(command, "nvim");
		assert.deepEqual(args, ["+call cursor(2, 3)", "--", path]);
		assert.deepEqual(options, { cwd, stdio: "inherit" });
		return { status: 0 };
	};
	await onFileLink(link, ctx, run, () => events.push("clear"));
	assert.deepEqual(events, ["stop", "clear", "nvim", "start", "render", "done"]);
	for (const fail of [() => ({ status: 1 }), () => ({ status: null, error: new Error("ENOENT") }), () => { throw new Error("spawn failed"); }]) {
		events.length = 0;
		await assert.rejects(onFileLink(link, ctx, fail, () => {}));
		assert.deepEqual(events, ["stop", "start", "render", "done"]);
	}
	await assert.rejects(onFileLink(link, { ...ctx, isIdle: () => false }, run, () => {}), /finish its turn/);
	await assert.rejects(onFileLink(link, { ...ctx, mode: "print" }, run, () => {}), /interactive Pi/);
	await assert.rejects(onFileLink({ ...link, line: 0 }, ctx, run, () => {}), /positive integers/);
	symlinkSync(process.execPath, join(cwd, "outside"));
	await assert.rejects(onFileLink({ path: join(cwd, "outside") }, ctx, run, () => {}), /outside the active workspace/);
	const positionPath = join(cwd, "position.txt");
	await onFileLink(link, ctx, (command, args, options) => {
		const record = `lua vim.fn.writefile({vim.fn.expand("%:p"), tostring(vim.fn.line(".")), tostring(vim.fn.col("."))}, ${JSON.stringify(positionPath)})`;
		return spawnSync(command, ["--headless", "--clean", "-n", args[0], "-c", record, "-c", "qa!", "--", path], { ...options, stdio: "pipe" });
	}, () => {});
	assert.deepEqual(readFileSync(positionPath, "utf8").trim().split("\n"), [path, "2", "3"]);
	console.log("PASS: safe Neovim argv; real Neovim opens file at 2:3; terminal stop/start/redraw on success and failure; busy/mode/path guards.");
} finally {
	rmSync(cwd, { recursive: true, force: true });
}
