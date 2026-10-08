import { closeSync, constants, fstatSync, openSync, readSync } from "node:fs";
import type { ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { StdinBuffer, TuiAltScreen, matchesKey, stripTerminalSequences, truncateToWidth, visibleWidth, type Component, type OverlayBounds, type OverlayHandle, type TUI, type TuiMouseEvent } from "@earendil-works/pi-tui";
import { displayPath, resolveFileLink, type FileLink } from "./file-link.ts";
import { highlightFile } from "./code-highlight.ts";
import { SyntaxDiff } from "./syntax-diff.ts";

const maxPreviewBytes = 256 * 1024;
const hoverMs = 350;
const contains = (bounds: OverlayBounds | undefined, x: number, y: number): boolean => !!bounds && x >= bounds.col && x < bounds.col + bounds.width && y >= bounds.row && y < bounds.row + bounds.height;

function previewFrame(title: string, body: Component, theme: Theme, lineCount: number): Component {
	return {
		render(width) {
			const inner = Math.max(0, width - 4);
			const frame = (value: string): string => {
				const clipped = truncateToWidth(value, inner, "…");
				return truncateToWidth(theme.fg("muted", "│ ") + clipped + " ".repeat(Math.max(0, inner - visibleWidth(clipped))) + theme.fg("muted", " │"), width, "");
			};
			const bodyRows = body.render(inner);
			const border = (left: string, right: string) => truncateToWidth(theme.fg("muted", left + "─".repeat(Math.max(0, width - 2)) + right), width, "");
			return [border("╭", "╮"), frame(theme.fg("mdLink", stripTerminalSequences(title).replace(/[\r\n\t]/g, " "))), ...Array.from({ length: lineCount }, (_, index) => frame(bodyRows[index] ?? "")), border("╰", "╯")];
		},
		handleMouse: event => body.handleMouse?.(event) ?? { handled: true, render: false },
		invalidate: () => body.invalidate(),
	};
}

export function diffPreview(link: FileLink, cwd: string, theme: Theme, diff: string, lineCount: number, width: number): { component: Component; height: number } {
	const title = `${displayPath(link.path, cwd)} · diff`;
	if (Buffer.byteLength(diff, "utf8") > maxPreviewBytes) return {
		height: lineCount + 3,
		component: previewFrame(title, { render: () => [theme.fg("dim", "Diff preview limited to 256 KiB; expand tool instead")], invalidate() {} }, theme, lineCount),
	};
	const syntax = new SyntaxDiff(stripTerminalSequences(diff), link.path, theme);
	let contentWidth = Math.max(0, width - 4);
	let rows = syntax.render(contentWidth);
	const height = lineCount;
	let offset = Math.max(0, Math.min(syntax.firstChangedRow - 3, rows.length - height));
	return {
		height: height + 3,
		component: previewFrame(title, {
			render(inner) {
				if (inner !== contentWidth) { rows = syntax.render(inner); contentWidth = inner; }
				offset = Math.max(0, Math.min(offset, rows.length - height));
				return rows.slice(offset, offset + height);
			},
			handleMouse(event) {
				if (event.type !== "wheel") return undefined;
				offset = Math.max(0, Math.min(offset + (event.wheelDelta ?? 0), rows.length - height));
				return { handled: true, render: true };
			},
			invalidate: () => { syntax.invalidate(); contentWidth = -1; },
		}, theme, lineCount),
	};
}

export function filePreview(link: FileLink, cwd: string, theme: Theme, lineCount = 12): { component: Component; height: number } {
	let title = displayPath(link.path, cwd);
	let rows: string[];
	try {
		const safe = resolveFileLink(link.path, cwd);
		if (!safe) throw new Error("File missing or outside workspace");
		if (link.line !== undefined && (!Number.isSafeInteger(link.line) || link.line < 1)) throw new Error("Invalid line number");
		const fd = openSync(safe.path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
		let code: string;
		try {
			if (!fstatSync(fd).isFile()) throw new Error("Preview requires a regular file");
			const buffer = Buffer.alloc(maxPreviewBytes + 1);
			let length = 0;
			while (length < buffer.length) {
				const count = readSync(fd, buffer, length, buffer.length - length, null);
				if (!count) break;
				length += count;
			}
			if (length > maxPreviewBytes) throw new Error("Preview limited to 256 KiB; click to open");
			const bytes = buffer.subarray(0, length);
			if (bytes.includes(0)) throw new Error("Binary file; click to open");
			code = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
		} finally { closeSync(fd); }
		const lines = highlightFile(stripTerminalSequences(code).replace(/\r\n/g, "\n").replace(/\t/g, "    "), safe.path, theme).split("\n");
		const target = Math.min(lines.length, link.line ?? 1);
		const start = Math.max(0, Math.min(target - 4, lines.length - lineCount));
		const end = Math.min(lines.length, start + lineCount);
		title += `:${target} · ${start + 1}–${end}`;
		const digits = String(end).length;
		rows = lines.slice(start, end).map((line, index) => theme.fg(index + start + 1 === target ? "warning" : "dim", `${index + start + 1 === target ? "›" : " "}${String(index + start + 1).padStart(digits)} │ `) + line);
	} catch (error) {
		rows = [theme.fg("dim", error instanceof Error ? error.message : String(error))];
	}
	return {
		height: lineCount + 3,
		component: previewFrame(title, { render: () => rows, invalidate() {} }, theme, lineCount),
	};
}

export class FileHoverPreview {
	private timer: ReturnType<typeof setTimeout> | undefined;
	private handle: OverlayHandle | undefined;
	private unsubscribe: (() => void) | undefined;
	private source: OverlayBounds | undefined;
	private link: FileLink | undefined;
	private focus: Component | null | undefined;
	private diff: string | undefined;

	constructor(private getContext: () => ExtensionContext | undefined, private getTui: () => TUI | undefined) {}

	close = (): void => {
		if (this.timer) clearTimeout(this.timer);
		this.timer = undefined;
		this.handle?.hide();
		this.handle = undefined;
		this.unsubscribe?.();
		this.unsubscribe = undefined;
		this.source = undefined;
		this.link = undefined;
		this.diff = undefined;
	};

	hover(link: FileLink, event: TuiMouseEvent, pathStart: number, pathEnd: number, diff?: string): void {
		const ctx = this.getContext();
		const tui = this.getTui();
		if (!ctx || !tui || ctx.mode !== "tui" || tui.mode !== "fullscreen") return;
		const source = { row: event.screenY, col: event.screenX - event.x + pathStart, width: pathEnd - pathStart, height: 1 };
		if (this.link?.path === link.path && this.link.line === link.line && this.diff === diff && this.source?.row === event.screenY) { this.source = source; return; }
		this.close();
		if (tui.hasOverlay()) return;
		this.link = link;
		this.diff = diff;
		this.source = source;
		const raw = new StdinBuffer();
		const observe = (chunk: string | Buffer): void => raw.process(chunk);
		raw.on("data", data => {
			if (data === "\x1b[O" || matchesKey(data, "escape")) { this.close(); return; }
			const mouse = /^\x1b\[<(\d+);(\d+);(\d+)[Mm]$/.exec(data);
			if (!mouse) return;
			const code = Number(mouse[1]), x = Number(mouse[2]) - 1, y = Number(mouse[3]) - 1;
			const inside = contains(this.handle?.getBounds(), x, y);
			if ((code >= 64 && !(this.diff !== undefined && inside)) ||
				(!contains(this.source, x, y) && !inside)) this.close();
		});
		raw.on("paste", this.close);
		process.stdin.on("data", observe);
		const offKeys = ctx.ui.onTerminalInput(data => {
			if (/^\x1b\[<\d+;\d+;\d+[Mm]$/.test(data)) return undefined;
			const visible = !!this.handle?.getBounds();
			const sameFocus = tui instanceof TuiAltScreen && tui.getFocusedComponent() === this.focus;
			this.close();
			if (visible && sameFocus && matchesKey(data, "escape")) return { consume: true };
			return undefined;
		});
		this.unsubscribe = () => { offKeys(); process.stdin.off("data", observe); raw.destroy(); };
		this.timer = setTimeout(() => {
			this.timer = undefined;
			if (this.getContext() !== ctx || this.getTui() !== tui || tui.hasOverlay() || !this.source) { this.close(); return; }
			const above = Math.max(0, this.source.row - 1), below = Math.max(0, tui.terminal.rows - this.source.row - 2);
			const useBelow = below >= above;
			const available = useBelow ? below : above;
			if (available < 6 || tui.terminal.columns < 24) { this.close(); return; }
			const width = tui.terminal.columns - 2;
			const preview = diff === undefined ? filePreview(link, ctx.cwd, ctx.ui.theme, available - 3)
				: diffPreview(link, ctx.cwd, ctx.ui.theme, diff, available - 3, width);
			this.focus = tui instanceof TuiAltScreen ? tui.getFocusedComponent() : undefined;
			this.handle = tui.showOverlay(preview.component, {
				nonCapturing: true, width,
				row: useBelow ? this.source.row + 1 : this.source.row - preview.height,
				col: 1, margin: 1,
			});
		}, hoverMs);
		this.timer.unref?.();
	}
}
