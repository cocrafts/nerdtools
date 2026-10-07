import type { Theme } from "@earendil-works/pi-coding-agent";
import type { Color, Component } from "@earendil-works/pi-tui";
import { backgroundAnsi, getTerminalColorMode, mixColors, sliceByColumn, truncateToWidth, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { diffWordsWithSpace } from "diff";
import { highlightFile } from "./code-highlight.ts";

interface DiffRow {
	prefix: "+" | "-" | " ";
	gutter: string;
	code: string;
	old?: string;
	new?: string;
	changed?: { start: number; end: number }[];
}

function parseRow(line: string): DiffRow | undefined {
	const match = /^([+\- ])(\s*\d+) (.*)$/.exec(line);
	if (!match) return undefined;
	return { prefix: match[1] as DiffRow["prefix"], gutter: `${match[1]}${match[2]} `, code: match[3].replaceAll("\t", "   ") };
}

function markChanges(rows: (DiffRow | undefined)[]): void {
	for (let i = 0; i < rows.length; i++) {
		if (rows[i]?.prefix !== "-") continue;
		const removed: DiffRow[] = [];
		const added: DiffRow[] = [];
		while (rows[i]?.prefix === "-") removed.push(rows[i++]!);
		while (rows[i]?.prefix === "+") added.push(rows[i++]!);
		i--;
		if (removed.length !== 1 || added.length !== 1) continue;
		removed[0].changed = [];
		added[0].changed = [];
		let oldColumn = 0;
		let newColumn = 0;
		for (const part of diffWordsWithSpace(removed[0].code, added[0].code)) {
			const width = visibleWidth(part.value);
			if (part.removed) removed[0].changed.push({ start: oldColumn, end: oldColumn + width });
			if (part.added) added[0].changed.push({ start: newColumn, end: newColumn + width });
			if (!part.added) oldColumn += width;
			if (!part.removed) newColumn += width;
		}
	}
}

function highlightRows(rows: (DiffRow | undefined)[], path: string, theme: Theme): void {
	let start = 0;
	while (start < rows.length) {
		if (!rows[start]) { start++; continue; }
		let end = start;
		while (rows[end]) end++;
		const block = rows.slice(start, end) as DiffRow[];
		for (const side of ["old", "new"] as const) {
			const sideRows = block.filter(row => row.prefix !== (side === "old" ? "+" : "-"));
			if (!sideRows.length) continue;
			const highlighted = highlightFile(sideRows.map(row => row.code).join("\n"), path, theme).split("\n");
			if (highlighted.length !== sideRows.length) throw new Error(`Diff highlighter changed ${side} line count for ${path}`);
			sideRows.forEach((row, index) => { row[side] = highlighted[index]; });
		}
		start = end;
	}
}

function emphasize(row: DiffRow, text: string, base: Color, strong: Color, theme: Theme): string {
	if (!row.changed?.length) return text;
	let column = 0;
	let result = "";
	const restore = backgroundAnsi(base, getTerminalColorMode());
	for (const change of row.changed) {
		result += sliceByColumn(text, column, change.start - column);
		const selected = sliceByColumn(text, change.start, change.end - change.start);
		result += theme.style(selected, { bg: strong }).replaceAll("\x1b[49m", restore);
		column = change.end;
	}
	return result + sliceByColumn(text, column, Math.max(0, visibleWidth(text) - column));
}

export class SyntaxDiff implements Component {
	private rows?: (DiffRow | undefined)[];

	constructor(private diff: string, private path: string, private theme: Theme) {}

	render(width: number): string[] {
		if (width <= 0) return [];
		const lines = this.diff.split("\n");
		if (!this.rows) {
			this.rows = lines.map(parseRow);
			highlightRows(this.rows, this.path, this.theme);
			markChanges(this.rows);
		}
		const rows = this.rows;
		const output: string[] = [];
		for (let i = 0; i < rows.length; i++) {
			const row = rows[i];
			if (!row) {
				output.push(truncateToWidth(this.theme.fg("dim", ` ${lines[i]}`), width, "…"));
				continue;
			}
			const token = row.prefix === "+" ? "toolDiffAdded" : row.prefix === "-" ? "toolDiffRemoved" : "muted";
			const base = mixColors(this.theme.colors.userMessageBg, this.theme.colors[token], 0.12, "srgb");
			const strong = mixColors(this.theme.colors.userMessageBg, this.theme.colors[token], 0.3, "srgb");
			let text = (row.prefix === "-" ? row.old : row.new) ?? "";
			if (row.prefix !== " ") text = emphasize(row, text, base, strong, this.theme);
			const full = this.theme.fg(token, row.gutter) + text;
			for (const wrapped of wrapTextWithAnsi(full, Math.max(1, width - 1))) {
				const line = truncateToWidth(` ${wrapped}`, width, "…");
				output.push(row.prefix === " " ? line : this.theme.style(line + " ".repeat(Math.max(0, width - visibleWidth(line))), { bg: base }));
			}
		}
		return output;
	}

	invalidate(): void { this.rows = undefined; }
}
