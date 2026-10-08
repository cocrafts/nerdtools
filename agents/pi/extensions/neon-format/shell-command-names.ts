import { execFile } from "node:child_process";
import { basename } from "node:path";

type ShellNode = { Type?: string; Value?: string; Parts?: ShellNode[]; Args?: ShellNode[]; Pos?: { Offset: number }; [key: string]: unknown };

function literal(word: ShellNode): string | undefined {
	if (word.Type === "Lit" || word.Type === "SglQuoted") return word.Value;
	if (!word.Parts) return undefined;
	const parts = word.Parts.map(literal);
	return parts.every(part => part !== undefined) ? parts.join("") : undefined;
}

export function commandNamesFromAst(ast: ShellNode): string {
	const calls: ShellNode[] = [];
	const visit = (value: unknown): void => {
		if (Array.isArray(value)) { value.forEach(visit); return; }
		if (!value || typeof value !== "object") return;
		const node = value as ShellNode;
		if (node.Type === "FuncDecl") return;
		if (node.Type === "CallExpr") calls.push(node);
		Object.values(node).forEach(visit);
	};
	visit(ast);
	const names = new Set<string>();
	for (const call of calls.sort((a, b) => (a.Pos?.Offset ?? 0) - (b.Pos?.Offset ?? 0))) {
		const words = (call.Args ?? []).map(literal);
		let index = 0;
		while (["env", "command", "exec", "nohup", "sudo"].includes(words[index] ?? "")) {
			index++;
			while (words[index]?.startsWith("-") || /^[A-Za-z_][A-Za-z_0-9]*=/.test(words[index] ?? "")) {
				const option = words[index++];
				if (["-u", "--unset", "-C", "--chdir", "-g", "--group", "--user"].includes(option ?? "")) index++;
			}
		}
		if (!call.Args?.length) continue;
		const name = words[index];
		if (!name || /\s|[\x00-\x1f\x7f]/.test(name)) { names.add("shell"); continue; }
		if (["set", "export", "unset", "cd", "true", "false", ":"].includes(name)) continue;
		names.add(basename(name));
	}
	const list = [...names];
	return list.length ? list.slice(0, 3).join(", ") + (list.length > 3 ? ", …" : "") : "shell";
}

export function shellCommandNames(command: string): Promise<string> {
	return new Promise(resolve => {
		const child = execFile("shfmt", ["-tojson"], { timeout: 1500, maxBuffer: 4 * 1024 * 1024 }, (error, stdout) => {
			if (error) { resolve("shell (name unavailable)"); return; }
			try { resolve(commandNamesFromAst(JSON.parse(stdout))); }
			catch { resolve("shell (name unavailable)"); }
		});
		child.stdin?.on("error", () => {});
		child.stdin?.end(command);
	});
}
