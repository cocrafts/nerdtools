import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { highlightCode } from "@earendil-works/pi-coding-agent";
import type { Component, TuiMouseEvent, TuiMouseEventResult } from "@earendil-works/pi-tui";
import { Container, Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { displayPath, resolveFileLink, type FileLink } from "./file-link.ts";
import { onFileLink } from "./on-file-link.ts";
import { highlightFile } from "./code-highlight.ts";
import { SyntaxDiff } from "./syntax-diff.ts";

const labels: Record<string, string> = {
	read: "→ Read", edit: "← Edit", write: "← Write", bash: "$", grep: "✱ Grep", find: "✱ Find", ls: "→ List",
};

export class ToolCallLine implements Component {
	private pathStart = 0;
	private pathEnd = 0;

	constructor(
		private prefix: string,
		private value: string,
		private suffix: string,
		private theme: Theme,
		private link: FileLink | undefined,
		private activate: (link: FileLink) => void,
		private language?: string,
	) {}

	render(width: number): string[] {
		const prefix = ` ${this.prefix} `;
		const value = this.link ? this.theme.underline(this.theme.fg("mdLink", this.value))
			: this.language ? highlightCode(this.value, this.language).join("\n") : this.theme.fg("toolTitle", this.value);
		this.pathStart = visibleWidth(prefix);
		this.pathEnd = Math.min(this.pathStart + visibleWidth(this.value), Math.max(0, width - 1));
		return [truncateToWidth(`${this.theme.fg("muted", prefix)}${value}${this.theme.fg("dim", this.suffix)}`, width, "…")];
	}

	handleMouse(event: TuiMouseEvent): TuiMouseEventResult | undefined {
		if (!this.link || event.y !== 0 || event.x < this.pathStart || event.x >= this.pathEnd || event.button !== "left" || event.type !== "click") return undefined;
		this.activate(this.link);
		return { handled: true, render: false };
	}

	invalidate(): void {}
}

export default function neonFormat(pi: ExtensionAPI): void {
	let context: ExtensionContext | undefined;
	let editorOpen = false;
	pi.on("session_start", (_event, ctx) => { context = ctx; });
	pi.on("session_shutdown", () => { context = undefined; });
	const activateFile = (link: FileLink): void => {
		const ctx = context;
		if (!ctx || editorOpen) return;
		editorOpen = true;
		void onFileLink(link, ctx).catch(error => {
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
		}).finally(() => { editorOpen = false; });
	};
	pi.registerToolRenderer((name, next) => {
		if (!Object.hasOwn(labels, name)) return next();
		const original = next();
		return {
			renderShell: "self",
			renderCall(args, theme, context) {
				const path = typeof args.path === "string" ? args.path : "";
				const value = name === "bash" ? String(args.command ?? "").split("\n")[0]
					: name === "grep" || name === "find" ? String(args.pattern ?? "")
					: path ? displayPath(path, context.cwd) : context.argsComplete ? "." : "…";
				const link = path && !["bash", "grep", "find"].includes(name) ? resolveFileLink(path, context.cwd) : undefined;
				if (link && name === "read" && Number.isSafeInteger(args.offset) && args.offset > 0) link.line = args.offset;
				const suffix = name === "read" && args.offset ? `:${args.offset}`
					: (name === "grep" || name === "find") && path ? ` in ${displayPath(path, context.cwd)}` : "";
				return new ToolCallLine(labels[name], value, suffix, theme, link, activateFile, name === "bash" ? "bash" : undefined);
			},
			renderResult(result, options, theme, context) {
				if (result.content.some(block => block.type === "image") && original?.renderResult) return original.renderResult(result, options, theme, context);
				const output = result.content.filter(block => block.type === "text").map(block => block.text).join("\n");
				if (options.isPartial) return new Text(theme.fg("warning", "  Running…"), 0, 0);
				const diff = (result.details as { diff?: unknown } | undefined)?.diff;
				if (!context.isError && name === "edit" && typeof diff === "string") {
					const lines = diff.split("\n");
					const added = lines.filter(line => line.startsWith("+") && !line.startsWith("+++")).length;
					const removed = lines.filter(line => line.startsWith("-") && !line.startsWith("---")).length;
					const summary = `  ${theme.fg("toolDiffAdded", `+${added}`)} ${theme.fg("toolDiffRemoved", `-${removed}`)}`;
					if (!options.expanded) return new Text(`${summary}${theme.fg("dim", " · ctrl+e to expand")}`, 0, 0);
					const view = new Container();
					view.addChild(new Text(summary, 0, 0));
					view.addChild(new SyntaxDiff(diff, String(context.args.path ?? ""), theme));
					return view;
				}
				if (options.expanded && name === "read" && !context.isError && typeof context.args.path === "string") {
					return new Text(highlightFile(output, context.args.path, theme), 1, 0);
				}
				if (options.expanded) return new Text(theme.fg(context.isError ? "error" : name === "bash" ? "dim" : "toolOutput", output), 1, 0);
				const lines = output ? output.split("\n") : [];
				if (context.isError || name === "bash") {
					const preview = lines.slice(0, 10).join("\n");
					const hint = lines.length > 10 ? `\n… ${lines.length - 10} more lines · ctrl+e to expand` : "";
					return new Text(theme.fg(context.isError ? "error" : "dim", preview + hint), 1, 0);
				}
				const summary = name === "write" ? "Written" : `${lines.length} lines`;
				return new Text(theme.fg("dim", `  ${summary} · ctrl+e to expand`), 0, 0);
			},
		};
	});
}
