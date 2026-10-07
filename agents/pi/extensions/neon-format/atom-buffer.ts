export interface AtomSpan {
	start: number;
	end: number;
	label: string;
	expansion?: string;
}

interface Snapshot { text: string; cursor: number }

const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const escape = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const normalize = (text: string): string => {
	if (typeof text !== "string") throw new TypeError("Editor text must be a string");
	return text.replace(/\r\n?/g, "\n").replace(/\t/g, "    ").replace(/[\x00-\x09\x0b-\x1f\x7f]/g, "");
};

export class AtomBuffer {
	private text = "";
	private cursor = 0;
	private atoms = new Map<string, string>();
	private undoStack: Snapshot[] = [];
	private redoStack: Snapshot[] = [];
	private expansionPattern?: RegExp;
	private spanPattern?: RegExp;
	private dirtyPatterns = true;
	private family?: RegExp;

	constructor(family?: RegExp) {
		if (family) {
			if (!(family instanceof RegExp)) throw new TypeError("Atomic token pattern must be a RegExp");
			this.family = new RegExp(family.source, family.flags.replace(/[gy]/g, ""));
			if (this.family.test("")) throw new Error("Atomic token pattern must not match an empty token");
		}
	}

	getText(): string { return this.text; }
	getCursor(): number { return this.cursor; }
	getExpandedText(): string { return this.expand(this.text); }

	setText(text: string): void {
		this.text = normalize(text);
		this.cursor = this.text.length;
		this.undoStack = [];
		this.redoStack = [];
	}

	setCursor(cursor: number): void {
		this.assertBoundary(cursor);
		this.cursor = cursor;
	}

	registerAtom(label: string, expansion: string): void {
		if (typeof label !== "string" || !label || /[\r\n\t\x00-\x1f\x7f]/.test(label)) throw new Error("Atom label must be nonempty single-line text without controls");
		if (typeof expansion !== "string") throw new TypeError(`Expansion for atom ${JSON.stringify(label)} must be a string`);
		const previous = this.atoms.get(label);
		if (previous !== undefined && previous !== expansion) throw new Error(`Conflicting expansion for atom ${JSON.stringify(label)}`);
		if (previous === expansion) return;
		this.atoms.set(label, expansion);
		this.dirtyPatterns = true;
	}

	getRegisteredAtoms(): [string, string][] { return [...this.atoms]; }

	clearAtoms(): void {
		this.atoms.clear();
		this.dirtyPatterns = true;
	}

	insertText(text: string): void {
		this.splice(this.cursor, this.cursor, normalize(text));
	}

	insertAtom(label: string, expansion: string): void {
		this.registerAtom(label, expansion);
		this.insertText(`${label} `);
	}

	collapseToAtom(start: number, end: number, label: string, expansion: string): void {
		this.assertRange(start, end);
		if (start === end) throw new Error("Cannot collapse an empty span to an atom");
		this.registerAtom(label, expansion);
		const cursor = this.cursor;
		this.splice(start, end, label);
		this.cursor = this.snap(cursor <= start ? cursor : cursor >= end ? cursor - (end - start) + label.length : start + label.length, "after");
	}

	getAtomSpans(): AtomSpan[] {
		this.compilePatterns();
		if (!this.spanPattern) return [];
		this.spanPattern.lastIndex = 0;
		const spans: AtomSpan[] = [];
		for (const match of this.text.matchAll(this.spanPattern)) {
			if (!match[0]) throw new Error(`Atomic token pattern matched an empty token at ${match.index}`);
			spans.push({ start: match.index, end: match.index + match[0].length, label: match[0], expansion: this.atoms.get(match[0]) });
		}
		return spans;
	}

	atomAt(cursor: number): AtomSpan | undefined {
		return this.getAtomSpans().find(span => cursor >= span.start && cursor < span.end);
	}

	expandRange(start: number, end: number): { start: number; end: number } {
		this.assertRange(start, end);
		const first = this.atomAt(start);
		if (first && first.start < start) start = first.start;
		const last = end > start ? this.atomAt(end - 1) : undefined;
		if (last && last.end > end) end = last.end;
		return { start, end };
	}

	replaceRange(start: number, end: number, text: string): void {
		const range = this.expandRange(start, end);
		this.splice(range.start, range.end, normalize(text));
	}

	copyRange(start: number, end: number): string {
		const range = this.expandRange(start, end);
		return this.expand(this.text.slice(range.start, range.end));
	}

	moveLeft(): void {
		const segments = [...graphemes.segment(this.text.slice(0, this.cursor))];
		this.cursor -= segments.at(-1)?.segment.length ?? 0;
	}

	moveRight(): void {
		const next = graphemes.segment(this.text.slice(this.cursor))[Symbol.iterator]().next().value;
		this.cursor += next?.segment.length ?? 0;
	}

	deleteBackward(): void {
		if (!this.cursor) return;
		const atom = this.atomAt(this.cursor - 1);
		if (atom) this.splice(this.snap(atom.start, "before"), this.snap(atom.end, "after"), "");
		else {
			const previous = [...graphemes.segment(this.text.slice(0, this.cursor))].at(-1);
			this.splice(this.cursor - (previous?.segment.length ?? 0), this.cursor, "");
		}
	}

	deleteForward(): void {
		if (this.cursor === this.text.length) return;
		const atom = this.atomAt(this.cursor);
		if (atom) this.splice(this.snap(atom.start, "before"), this.snap(atom.end, "after"), "");
		else {
			const next = graphemes.segment(this.text.slice(this.cursor))[Symbol.iterator]().next().value;
			this.splice(this.cursor, this.cursor + (next?.segment.length ?? 0), "");
		}
	}

	undo(): boolean { return this.restore(this.undoStack, this.redoStack); }
	redo(): boolean { return this.restore(this.redoStack, this.undoStack); }

	private expand(text: string): string {
		this.compilePatterns();
		if (!this.expansionPattern) return text;
		this.expansionPattern.lastIndex = 0;
		return text.replace(this.expansionPattern, label => this.atoms.get(label)!);
	}

	private compilePatterns(): void {
		if (!this.dirtyPatterns) return;
		const sources = [...this.atoms.keys()].sort((a, b) => b.length - a.length).map(escape);
		this.expansionPattern = sources.length ? new RegExp(sources.join("|"), "g") : undefined;
		if (this.family) sources.unshift(`(?:${this.family.source})`);
		this.spanPattern = sources.length ? new RegExp(sources.join("|"), `${this.family?.flags ?? "u"}g`) : undefined;
		this.dirtyPatterns = false;
	}

	private assertRange(start: number, end: number): void {
		if (start > end) throw new RangeError(`Reversed editor range ${start}..${end}`);
		this.assertBoundary(start);
		this.assertBoundary(end);
	}

	private assertBoundary(cursor: number): void {
		if (!Number.isSafeInteger(cursor) || cursor < 0 || cursor > this.text.length) throw new RangeError(`Editor offset ${cursor} is outside 0..${this.text.length}`);
		if (cursor === this.text.length || cursor === 0) return;
		for (const segment of graphemes.segment(this.text)) if (segment.index === cursor) return;
		throw new RangeError(`Editor offset ${cursor} splits a grapheme`);
	}

	private snap(cursor: number, affinity: "before" | "after"): number {
		for (const segment of graphemes.segment(this.text)) {
			const end = segment.index + segment.segment.length;
			if (cursor > segment.index && cursor < end) return affinity === "before" ? segment.index : end;
		}
		return cursor;
	}

	private splice(start: number, end: number, text: string): void {
		this.assertRange(start, end);
		const next = this.text.slice(0, start) + text + this.text.slice(end);
		if (next === this.text) return;
		this.undoStack.push({ text: this.text, cursor: this.cursor });
		if (this.undoStack.length > 100) this.undoStack.shift();
		this.redoStack = [];
		this.text = next;
		this.cursor = this.snap(start + text.length, "after");
	}

	private restore(from: Snapshot[], to: Snapshot[]): boolean {
		const snapshot = from.pop();
		if (!snapshot) return false;
		to.push({ text: this.text, cursor: this.cursor });
		this.text = snapshot.text;
		this.cursor = snapshot.cursor;
		return true;
	}
}
