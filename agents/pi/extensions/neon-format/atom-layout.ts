import type { AtomSpan } from "./atom-buffer.ts";
import { AtomBuffer } from "./atom-buffer.ts";

export interface AtomCell {
	start: number;
	end: number;
	text: string;
	source: string;
	columns: number;
	atom?: AtomSpan;
}

export interface AtomRow {
	start: number;
	end: number;
	hardBreak: boolean;
	softBreak: boolean;
	cells: AtomCell[];
}

const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });

export function layoutAtoms(buffer: AtomBuffer, width: number, measure: (text: string) => number): AtomRow[] {
	if (!Number.isSafeInteger(width) || width < 1) throw new RangeError(`Invalid editor layout width ${width}`);
	const text = buffer.getText();
	const spans = buffer.getAtomSpans();
	const rows: AtomRow[] = [];
	let cells: AtomCell[] = [];
	let start = 0;
	let columns = 0;
	let atomIndex = 0;
	const flush = (count: number, end: number, hardBreak = false, softBreak = false): void => {
		rows.push({ start, end, hardBreak, softBreak, cells: cells.slice(0, count) });
		cells = cells.slice(count);
		start = end + (hardBreak ? 1 : 0);
		columns = cells.reduce((sum, cell) => sum + cell.columns, 0);
	};
	for (const grapheme of graphemes.segment(text)) {
		if (grapheme.segment === "\n") {
			flush(cells.length, grapheme.index, true);
			continue;
		}
		const rawColumns = measure(grapheme.segment);
		if (!Number.isSafeInteger(rawColumns) || rawColumns < 0) throw new Error(`Invalid grapheme width ${rawColumns} for ${JSON.stringify(grapheme.segment)}`);
		const shown = rawColumns > width ? "…" : grapheme.segment;
		const size = rawColumns > width ? 1 : rawColumns;
		while (cells.length && columns + size > width) {
			let breakAt = cells.length;
			for (let i = cells.length - 1; i >= 0; i--) {
				if (/^\s+$/u.test(cells[i].source)) { breakAt = i + 1; break; }
			}
			flush(breakAt, cells[breakAt - 1].end, false, true);
		}
		while (atomIndex < spans.length && spans[atomIndex].end <= grapheme.index) atomIndex++;
		const span = spans[atomIndex];
		const end = grapheme.index + grapheme.segment.length;
		const atom = span && span.start <= grapheme.index && span.end >= end ? span : undefined;
		cells.push({ start: grapheme.index, end, source: grapheme.segment, text: shown, columns: size, atom });
		columns += size;
	}
	flush(cells.length, text.length);
	return rows;
}

export function caretInRows(rows: readonly AtomRow[], cursor: number): { row: number; column: number } {
	if (!Number.isSafeInteger(cursor) || cursor < 0) throw new RangeError(`Invalid editor caret ${cursor}`);
	for (let row = 0; row < rows.length; row++) {
		const entry = rows[row];
		if (cursor < entry.start || cursor > entry.end) continue;
		if (cursor === entry.end && entry.softBreak) continue;
		let column = 0;
		for (const cell of entry.cells) {
			if (cursor <= cell.start) return { row, column };
			if (cursor < cell.end) throw new RangeError(`Editor caret ${cursor} splits a layout grapheme`);
			column += cell.columns;
		}
		return { row, column };
	}
	throw new RangeError(`Editor caret ${cursor} is outside the layout`);
}

export function cursorInRow(row: AtomRow, column: number): number {
	if (!Number.isFinite(column) || column < 0) throw new RangeError(`Invalid editor hit column ${column}`);
	let current = 0;
	for (const cell of row.cells) {
		if (column < current + cell.columns) return cell.start;
		current += cell.columns;
	}
	return row.softBreak && row.cells.length ? row.cells.at(-1)!.start : row.end;
}
