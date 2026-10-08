import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { highlightCode } from "@earendil-works/pi-coding-agent";
import type { Component, TuiMouseEvent, TuiMouseEventResult } from "@earendil-works/pi-tui";
import { Container, Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { displayPath, resolveFileLink, type FileLink } from "./file-link.ts";
import { onFileLink } from "./on-file-link.ts";
import { highlightFile } from "./code-highlight.ts";
import { registerSkillInput } from "./skill-input.ts";
import { SyntaxDiff } from "./syntax-diff.ts";
import { shellCommandNames } from "./shell-command-names.ts";
import { FileHoverPreview } from "./file-hover-preview.ts";

const labels: Record<string, string> = {
	read: " Read", edit: "← Edit", write: "← Write", bash: "$", grep: "✱ Grep", find: "✱ Find", ls: "→ List",
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
		private hover?: (link: FileLink, event: TuiMouseEvent, start: number, end: number) => void,
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
		if (!this.link || event.y !== 0 || event.x < this.pathStart || event.x >= this.pathEnd) return undefined;
		if (event.type === "move" && event.button === "none") {
			this.hover?.(this.link, event, this.pathStart, this.pathEnd);
			return { handled: true, render: false };
		}
		if (event.button !== "left" || event.type !== "click") return undefined;
		this.activate(this.link);
		return { handled: true, render: false };
	}

	invalidate(): void {}
}

export class OutputPreview implements Component {
	private body: Text;

	constructor(output: string, private theme: Theme, color: "dim" | "toolOutput" | "error", private padding = 0) {
		this.body = new Text(theme.fg(color, output), padding, 0);
	}

	render(width: number): string[] {
		const rows = this.body.render(width);
		if (rows.length <= 3) return rows;
		const hint = this.theme.fg("dim", " …");
		const available = Math.max(0, width - this.padding);
		return [...rows.slice(0, 2), truncateToWidth(rows[2], Math.max(0, available - visibleWidth(hint)), "") + truncateToWidth(hint, available, "…") + " ".repeat(Math.min(this.padding, Math.max(0, width)))];
	}

	invalidate(): void { this.body.invalidate(); }
}

export default function neonFormat(pi: ExtensionAPI): void {
	const getTui = registerSkillInput(pi);
	let context: ExtensionContext | undefined;
	const preview = new FileHoverPreview(() => context, getTui);
	let editorOpen = false;
	pi.on("session_start", (_event, ctx) => { preview.close(); context = ctx; });
	pi.on("session_shutdown", () => { preview.close(); context = undefined; });
	pi.on("session_before_switch", preview.close);
	pi.on("session_before_tree", preview.close);
	pi.on("session_before_fork", preview.close);
	pi.on("input", preview.close);
	const activateFile = (link: FileLink): void => {
		preview.close();
		const ctx = context;
		if (!ctx || editorOpen) return;
		editorOpen = true;
		void onFileLink(link, ctx).catch(error => {
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
		}).finally(() => { editorOpen = false; });
	};
	pi.registerToolRenderer((name, next) => {
		if (!Object.hasOwn(labels, name)) {
			const original = next();
			if (name !== "cc_list_peers" && original?.renderResult) return original;
			return {
				...original,
				...(name === "cc_list_peers" ? { renderShell: "self" as const, renderCall: (_args: unknown, theme: Theme) => new Text(theme.fg("dim", " › Peers"), 0, 0) } : {}),
				renderResult(result, options, theme, context) {
					const output = result.content.filter(block => block.type === "text").map(block => block.text).join("\n");
					const color = context.isError ? "error" : name === "cc_list_peers" ? "dim" : "toolOutput";
					const padding = name === "cc_list_peers" ? 1 : 0;
					return options.expanded ? new Text(theme.fg(color, output), padding, 0) : new OutputPreview(output, theme, color, padding);
				},
			};
		}
		const original = next();
		return {
			renderShell: "self",
			renderCall(args, theme, context) {
				if (name === "bash") return {
					render: (width: number) => context.state.complete && !context.expanded && !context.isError ? []
						: new Text(` ${theme.fg("muted", "$ ")}${highlightCode(String((args as { command?: unknown }).command ?? ""), "bash").join("\n")}`, 0, 0).render(width),
					invalidate() {},
				};
				const path = typeof args.path === "string" ? args.path : "";
				const value = name === "grep" || name === "find" ? String(args.pattern ?? "")
					: path ? displayPath(path, context.cwd) : context.argsComplete ? "." : "…";
				const link = path && !["bash", "grep", "find"].includes(name) ? resolveFileLink(path, context.cwd) : undefined;
				if (link && name === "read" && Number.isSafeInteger(args.offset) && args.offset > 0) link.line = args.offset;
				const suffix = name === "read" && args.offset ? `:${args.offset}`
					: (name === "grep" || name === "find") && path ? ` in ${displayPath(path, context.cwd)}` : "";
				return new ToolCallLine(labels[name], value, suffix, theme, link, activateFile, undefined,
					(link, event, start, end) => { if (!editorOpen) preview.hover(link, event, start, end); });
			},
			renderResult(result, options, theme, context) {
				if (result.content.some(block => block.type === "image") && original?.renderResult) return original.renderResult(result, options, theme, context);
				const output = result.content.filter(block => block.type === "text").map(block => block.text).join("\n");
				if (name === "bash") {
					context.state.complete = !options.isPartial;
					if (options.isPartial) return new Text(output ? theme.fg("dim", output) : theme.fg("warning", "  Running…"), 1, 0);
					if (!options.expanded && !context.isError) {
						if (!context.state.summaryRequested) {
							context.state.summaryRequested = true;
							void shellCommandNames(String((context.args as { command?: unknown }).command ?? "")).then(names => {
								context.state.shellSummary = names;
								context.invalidate();
							});
						}
						return {
							render: (width: number) => {
								const names = context.state.shellSummary ?? "shell";
								return new Text(theme.fg("dim", `  Run command: ${names}`), 0, 0).render(width);
							},
							invalidate() {},
						};
					}
				}
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
					return new OutputPreview(output, theme, context.isError ? "error" : "dim", 1);
				}
				const summary = name === "write" ? "Written" : `${lines.length} lines`;
				return new Text(theme.fg("dim", `  ${summary} · ctrl+e to expand`), 0, 0);
			},
		};
	});
}
