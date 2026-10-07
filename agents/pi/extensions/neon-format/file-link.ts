import { realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve, sep } from "node:path";

export interface FileLink {
	path: string;
	line?: number;
	column?: number;
}

export function resolveFileLink(input: string, cwd: string): FileLink | undefined {
	const match = /^(.*?)(?::([1-9]\d*))?(?::([1-9]\d*))?$/.exec(input);
	if (!match) return undefined;
	const candidate = match[1].startsWith("~/") ? resolve(homedir(), match[1].slice(2)) : resolve(cwd, match[1]);
	try {
		const root = realpathSync(cwd);
		const path = realpathSync(candidate);
		const within = relative(root, path);
		if (within === ".." || within.startsWith(`..${sep}`) || isAbsolute(within) || !statSync(path).isFile()) return undefined;
		return { path, line: match[2] ? Number(match[2]) : undefined, column: match[3] ? Number(match[3]) : undefined };
	} catch (error) {
		if (["ENOENT", "ENOTDIR"].includes((error as NodeJS.ErrnoException).code ?? "")) return undefined;
		throw error;
	}
}

export function displayPath(input: string, cwd: string): string {
	const absolute = input.startsWith("~/") ? resolve(homedir(), input.slice(2)) : resolve(cwd, input);
	const local = relative(cwd, absolute);
	if (local !== ".." && !local.startsWith(`..${sep}`) && !isAbsolute(local)) return local || ".";
	const home = relative(homedir(), absolute);
	return home !== ".." && !home.startsWith(`..${sep}`) && !isAbsolute(home) ? `~/${home}` : absolute;
}
