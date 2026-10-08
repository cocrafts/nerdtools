import { spawnSync } from "node:child_process";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { resolveFileLink, type FileLink } from "./file-link.ts";

interface EditorResult {
	status: number | null;
	signal?: NodeJS.Signals | null;
	error?: Error;
}

export type EditorProcess = (command: string, args: string[], options: { cwd: string; stdio: "inherit" }) => EditorResult;

export async function onFileLink(
	link: FileLink,
	ctx: ExtensionContext,
	run: EditorProcess = (command, args, options) => spawnSync(command, args, options),
	clearScreen: () => void = () => { process.stdout.write("\x1b[2J\x1b[H"); },
): Promise<void> {
	if (ctx.mode !== "tui") throw new Error("Neovim file links require interactive Pi");
	if (!ctx.isIdle()) return;
	if (!resolveFileLink(link.path, ctx.cwd)) throw new Error(`File link is missing or outside the active workspace: ${link.path}`);
	for (const position of [link.line, link.column]) {
		if (position !== undefined && (!Number.isSafeInteger(position) || position < 1)) throw new Error("File link line and column must be positive integers");
	}
	const args: string[] = [];
	if (link.line !== undefined || link.column !== undefined) args.push(`+call cursor(${link.line ?? 1}, ${link.column ?? 1})`);
	args.push("--", link.path);
	const result = await ctx.ui.custom<EditorResult>((tui, _theme, _keys, done) => {
		let result: EditorResult;
		try {
			tui.stop();
			clearScreen();
			result = run("nvim", args, { cwd: ctx.cwd, stdio: "inherit" });
		} catch (error) {
			result = { status: null, error: error instanceof Error ? error : new Error(String(error)) };
		} finally {
			tui.start();
			tui.requestRender(true);
		}
		done(result);
		return { render: () => [], invalidate() {} };
	});
	if (result.error) throw new Error(`Cannot open Neovim: ${result.error.message}`);
	if (result.status !== 0) throw new Error(`Neovim exited with ${result.signal ? `signal ${result.signal}` : `status ${result.status}`}`);
}
