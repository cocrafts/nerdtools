import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const jiti = createJiti(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
const source = resolve(here, "../extensions/neon-format");
const { AtomBuffer } = await jiti.import(join(source, "atom-buffer.ts"));
const { layoutAtoms, caretInRows, cursorInRow } = await jiti.import(join(source, "atom-layout.ts"));
const skills = await jiti.import(join(source, "skill-atoms.ts"));
const { visibleWidth } = await import(pathToFileURL(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js")).href);
const reference = JSON.parse(readFileSync(join(here, "fixtures/omp-atoms.json"), "utf8"));
assert.equal(reference.revision, "d700137b969d83059eea88c6b1502e70c8a769a3");
const oracleCode = `export class OmpAtomOracle {
 atomicTokenPattern?: RegExp;
 #atoms = new Map<string,string>();
 #atomsRevision = 0;
 #pastes = new Map<number,string>();
 #atomicTokenSource?: string;
 #atomicTokenRe?: RegExp;
 ${Object.values(reference.editorMethods).join("\n")}
 expand(text:string) { return this.#expandPasteMarkers(text); }
 spanAt(text:string,col:number) { return this.#atomicTokenAt(text,col); }
 range(text:string,start:number,end:number) { return this.#expandRangeOverAtomicTokens(text,start,end); }
}
const SKILL_TOKEN_RE = ${reference.skillTokenRegex};
const skillChipLabel = (name:string) => ' '+name;
const skillToken = (name:string) => '/skill:'+name;
${Object.values(reference.skillFunctions).join("\n")}`;
const oracleModule = await jiti.evalModule(oracleCode, { filename: join(here, "fixtures/omp-atoms-reference.ts"), async: true });
const { OmpAtomOracle } = oracleModule;
const known = new Set(["trace-nim", "split-commit", "root.foo", "pkg/name"]);
const cases = [
	"Review /skill:trace-nim rồi /skill:split-commit",
	"/skill:trace-nim /skill:split-commit",
	"Review\n/skill:trace-nim\nthen /skill:split-commit",
	"/model other /skill:trace-nim",
	"!echo /skill:trace-nim", "$ echo /skill:trace-nim", "$$ echo /skill:trace-nim",
	"${value} /skill:trace-nim", "$value /skill:trace-nim",
	"/skill:unknown", "Use /skill:pkg/name/deep", "Use /skill:root.foo /skill:pkg/name",
	"Use `/skill:trace-nim` as an example", "Use /skill:trace-nim. as an example",
];
for (const text of cases) {
	const buffer = new AtomBuffer(skills.SKILL_CHIP_PATTERN);
	const expected = new Map();
	const display = skills.collapseSkillTokens(text, known, (label, expansion) => buffer.registerAtom(label, expansion));
	const comparison = oracleModule.collapseSkillTokens(text, name => known.has(name), (label, expansion) => expected.set(label, expansion));
	assert.equal(display, comparison);
	assert.equal(skills.allowsSkillTokens(text), oracleModule.allowsSkillTokens(text));
	buffer.setText(display);
	assert.equal(buffer.getExpandedText(), text);
}
const buffer = new AtomBuffer(skills.SKILL_CHIP_PATTERN);
const oracle = new OmpAtomOracle();
oracle.atomicTokenPattern = skills.SKILL_CHIP_PATTERN;
for (const name of known) {
	buffer.registerAtom(` ${name}`, `/skill:${name}`);
	oracle.registerAtom(` ${name}`, `/skill:${name}`);
}
const display = "a  trace-nim b  split-commit c";
buffer.setText(display);
assert.equal(buffer.getExpandedText(), oracle.expand(display));
let comparisons = 0;
for (let start = 0; start <= display.length; start++) {
	const expected = oracle.spanAt(display, start);
	const actual = buffer.atomAt(start);
	assert.deepEqual(actual ? { start: actual.start, end: actual.end } : undefined, expected);
	for (let end = start; end <= display.length; end++) {
		assert.deepEqual(buffer.expandRange(start, end), oracle.range(display, start, end));
		comparisons++;
	}
}
for (const span of buffer.getAtomSpans()) {
	for (let cursor = span.start + 1; cursor <= span.end; cursor++) {
		buffer.setText(display); buffer.setCursor(cursor); buffer.deleteBackward();
		assert.equal(buffer.getText(), display.slice(0, span.start) + display.slice(span.end));
		assert.equal(buffer.getCursor(), span.start);
		assert.equal(buffer.undo(), true);
		assert.equal(buffer.getText(), display);
		assert.equal(buffer.getCursor(), cursor);
		assert.equal(buffer.redo(), true);
		assert.ok(!buffer.getText().includes(span.label));
	}
	for (let cursor = span.start; cursor < span.end; cursor++) {
		buffer.setText(display); buffer.setCursor(cursor); buffer.deleteForward();
		assert.equal(buffer.getText(), display.slice(0, span.start) + display.slice(span.end));
	}
}
buffer.setText(display);
const first = buffer.getAtomSpans()[0];
assert.equal(buffer.copyRange(first.start + 2, first.end - 1), "/skill:trace-nim");
buffer.replaceRange(first.start + 2, first.end - 1, "replacement");
assert.equal(buffer.getText(), display.slice(0, first.start) + "replacement" + display.slice(first.end));
buffer.undo();
assert.equal(buffer.getText(), display);
buffer.setCursor(first.start + 3);
buffer.moveRight(); assert.equal(buffer.getCursor(), first.start + 4);
buffer.moveLeft(); assert.equal(buffer.getCursor(), first.start + 3);
buffer.setText("Review ");
buffer.insertAtom(" trace-nim", "/skill:trace-nim");
assert.equal(buffer.getExpandedText(), "Review /skill:trace-nim ");
buffer.undo(); assert.equal(buffer.getText(), "Review ");
buffer.redo(); assert.equal(buffer.getText(), "Review  trace-nim ");
buffer.undo(); buffer.insertText("different"); assert.equal(buffer.redo(), false);
buffer.setText("Review /skill:trace-nim then");
buffer.setCursor(buffer.getText().length);
buffer.collapseToAtom(7, 23, " trace-nim", "/skill:trace-nim");
assert.equal(buffer.getText(), "Review  trace-nim then");
assert.equal(buffer.getCursor(), buffer.getText().length);
assert.equal(buffer.getExpandedText(), "Review /skill:trace-nim then");
buffer.undo(); assert.equal(buffer.getText(), "Review /skill:trace-nim then");
for (const [text, cursor] of [["/skill:trace-nim", 0], ["/skill:trace-nim", 8]]) {
	buffer.setText(text); buffer.setCursor(cursor);
	buffer.collapseToAtom(0, text.length, " trace-nim", "/skill:trace-nim");
	assert.equal(buffer.getCursor(), cursor === 0 ? 0 : " trace-nim".length);
}
const nested = new AtomBuffer();
const nestedOracle = new OmpAtomOracle();
for (const [label, expansion] of [["outer", "inner"], ["inner", "body"], ["#1", "one"], ["#10", "ten"], ["[literal.*]", "safe"]]) {
	nested.registerAtom(label, expansion); nestedOracle.registerAtom(label, expansion);
}
nested.setText("outer inner #1 #10 [literal.*]");
assert.equal(nested.getExpandedText(), "inner body one ten safe");
assert.equal(nested.getExpandedText(), nestedOracle.expand(nested.getText()));
const unicode = new AtomBuffer();
const emoji = "👩🏽‍💻";
unicode.setText("a" + emoji + "e\u0301");
unicode.deleteBackward(); assert.equal(unicode.getText(), "a" + emoji);
unicode.deleteBackward(); assert.equal(unicode.getText(), "a");
unicode.undo(); assert.equal(unicode.getText(), "a" + emoji);
unicode.setCursor(1); unicode.deleteForward(); assert.equal(unicode.getText(), "a");
unicode.setText("👩💻"); unicode.setCursor("👩".length); unicode.insertText("\u200d");
assert.equal(unicode.getText(), "👩‍💻"); assert.equal(unicode.getCursor(), unicode.getText().length);
unicode.deleteBackward(); assert.equal(unicode.getText(), "");
for (const text of ["", "\n", "a\n\n", "🌙界e\u0301 " + emoji, display + "\n" + display, "verylongword " + display]) {
	buffer.setText(text);
	for (const width of [1, 2, 8, 20, 40, 80]) {
		const rows = layoutAtoms(buffer, width, visibleWidth);
		assert.equal(rows.map(row => row.cells.map(cell => cell.source).join("") + (row.hardBreak ? "\n" : "")).join(""), text);
		for (const row of rows) {
			assert.ok(row.cells.reduce((sum, cell) => sum + cell.columns, 0) <= width);
			assert.ok(visibleWidth(row.cells.map(cell => cell.text).join("")) <= width);
			for (const cell of row.cells) {
				if (cell.atom) assert.equal(text.slice(cell.atom.start, cell.atom.end), cell.atom.label);
			}
		}
		const boundaries = [...new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(text)].map(segment => segment.index).concat(text.length);
		for (const cursor of boundaries) {
			const position = caretInRows(rows, cursor);
			const inverse = cursorInRow(rows[position.row], position.column);
			assert.equal(inverse, cursor);
		}
	}
}
assert.throws(() => new AtomBuffer(/x*/), /empty token/);
const badPattern = new AtomBuffer(/(?=x)/); badPattern.setText("x");
assert.throws(() => badPattern.getAtomSpans(), /empty token/);
assert.throws(() => buffer.registerAtom("", "raw"), /Atom label/);
assert.throws(() => buffer.registerAtom("a\nb", "raw"), /Atom label/);
assert.throws(() => buffer.registerAtom(" trace-nim", "different"), /Conflicting/);
buffer.setText(emoji);
assert.throws(() => buffer.setCursor(1), /splits a grapheme/);
assert.throws(() => buffer.setCursor(-1), /outside/);
assert.throws(() => layoutAtoms(buffer, 0, visibleWidth), /layout width/);
assert.throws(() => caretInRows([], NaN), /Invalid editor caret/);
assert.throws(() => layoutAtoms(buffer, 8, () => -1), /Invalid grapheme width/);
console.log(`PASS: ${comparisons} range comparisons against pinned OMP; inline/multi-skill round-trip; whole-chip deletion/replacement/copy; Unicode cursor/undo/redo; wrap and mouse/caret maps at widths 1–80; unsafe declarations fail loud.`);
