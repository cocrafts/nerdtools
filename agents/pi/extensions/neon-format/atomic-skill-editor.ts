import { CustomEditor, type KeybindingsManager, type Theme } from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, SelectList, decodeKittyPrintable, isKeyRelease, matchesKey, parseColor, parseKey, stripTerminalSequences, visibleWidth, type AutocompleteProvider, type AutocompleteSuggestions, type EditorTheme, type TUI, type TuiMouseEvent, type TuiMouseEventResult } from "@earendil-works/pi-tui";
import { AtomBuffer } from "./atom-buffer.ts";
import { layoutAtoms, caretInRows, cursorInRow, type AtomRow } from "./atom-layout.ts";
import { SKILL_CHIP_PATTERN, allowsSkillTokens, collapseSkillTokens } from "./skill-atoms.ts";
import { skillPromptInput } from "./skill-submit.ts";

export interface SkillDraft { text: string; cursor: number; atoms: [string, string][] }
const herdrPaneBorder = parseColor("#89b4fa");
const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });
const printable = (data: string): string | undefined => {
	const key = parseKey(data);
	if (key?.includes("+") && !key.startsWith("shift+")) return undefined;
	return decodeKittyPrintable(data) ?? (data && !/[\x00-\x1f\x7f]/.test(data) ? data : undefined);
};

export class AtomicSkillEditor extends CustomEditor {
	readonly buffer = new AtomBuffer(SKILL_CHIP_PATTERN);
	private editorKeys: KeybindingsManager;
	private editorTheme: EditorTheme;
	private completionProvider?: AutocompleteProvider;
	private suggestions?: AutocompleteSuggestions;
	private menu?: SelectList;
	private forcedCompletion = false;
	private completionTrigger = /(?:^|\s)[([{<`]*(?:@"[^"]*|[@#][^\s]*)$/u;
	private completionAbort?: AbortController;
	private rows: AtomRow[] = [];
	private layoutKey = "";
	private contentWidth = 78;
	private renderedPadding = 0;
	private firstVisible = 0;
	private visibleRows = 1;
	private preferredColumn?: number;
	private bufferedPaste?: string;
	private pasteNumber = 0;
	private promptHistory: { canonical: string; draft: SkillDraft }[] = [];
	private historyPosition = -1;
	private savedDraft?: SkillDraft;
	private submittedDraft?: { canonical: string; draft: SkillDraft };
	private kills: SkillDraft[] = [];
	private lastKill?: "backward" | "forward";
	private yankSpan?: { start: number; end: number; index: number };
	private jumpDirection?: "forward" | "backward";
	private terminalFocused = true;

	constructor(tui: TUI, theme: EditorTheme, keys: KeybindingsManager, private known: () => ReadonlySet<string>, private palette: () => Theme, private beforeSubmit: (text: string) => boolean = () => true, private reportError: (error: Error) => void = error => { throw error; }) {
		super(tui, theme, keys, { embedWorkingStatus: true });
		this.editorKeys = keys;
		this.editorTheme = theme;
	}

	getText(): string { return this.buffer.getText(); }
	getExpandedText(): string { return this.buffer.getExpandedText(); }
	getLines(): string[] { return this.getText().split("\n"); }
	getCursor(): { line: number; col: number } {
		const prefix = this.getText().slice(0, this.buffer.getCursor()).split("\n");
		return { line: prefix.length - 1, col: prefix.at(-1)!.length };
	}
	getDraft(): SkillDraft { return { text: this.getText(), cursor: this.buffer.getCursor(), atoms: this.buffer.getRegisteredAtoms() }; }
	restoreDraft(draft: SkillDraft): void {
		this.closeMenu();
		this.buffer.clearAtoms();
		for (const [label, expansion] of draft.atoms) {
			this.buffer.registerAtom(label, expansion);
			const paste = /^\[Paste #(\d+)\]$/.exec(label);
			if (paste) this.pasteNumber = Math.max(this.pasteNumber, Number(paste[1]));
		}
		this.buffer.setText(draft.text);
		this.buffer.setCursor(draft.cursor);
		this.changed(false);
	}
	setText(text: string): void {
		this.closeMenu();
		this.buffer.clearAtoms();
		const display = collapseSkillTokens(text, this.known(), (label, expansion) => this.buffer.registerAtom(label, expansion));
		this.buffer.setText(display);
		this.historyPosition = -1;
		this.preferredColumn = undefined;
		this.lastKill = undefined;
		this.yankSpan = undefined;
		this.changed(false);
	}
	insertTextAtCursor(text: string): void { this.buffer.insertText(text); this.changed(); }
	setAutocompleteProvider(provider: AutocompleteProvider): void {
		this.closeMenu();
		this.completionProvider = provider;
		const characters = [...new Set(["@", "#", ...(provider.triggerCharacters ?? [])])].filter(char => char.length === 1 && char !== "/" && !/\s/u.test(char)).map(char => char.replace(/[\\\]\^\-]/g, "\\$&")).join("");
		this.completionTrigger = new RegExp('(?:^|\\s)[([{<`]*(?:@"[^"]*|[' + characters + '][^\\s]*)$', "u");
	}
	isShowingAutocomplete(): boolean { return Boolean(this.menu); }
	setTerminalFocused(focused: boolean): void {
		if (this.terminalFocused === focused) return;
		this.terminalFocused = focused;
		this.tui.requestRender();
	}
	dispose(): void { this.closeMenu(); }
	invalidate(): void { this.layoutKey = ""; this.menu?.invalidate(); }
	addToHistory(text: string): void {
		text = skillPromptInput(text);
		if (!text.trim() || this.promptHistory[0]?.canonical === text.trim()) return;
		const restored = collapseSkillTokens(text, this.known(), () => {});
		const draft = this.submittedDraft?.canonical.trim() === text.trim() ? this.submittedDraft.draft : { text: restored, cursor: restored.length, atoms: [...this.known()].map(name => [` ${name}`, `/skill:${name}`] as [string, string]) };
		this.promptHistory.unshift({ canonical: text.trim(), draft });
		this.promptHistory.length = Math.min(this.promptHistory.length, 100);
		this.historyPosition = -1;
	}

	private updateRows(): void {
		const key = `${this.contentWidth}\0${this.getText()}`;
		if (key === this.layoutKey) return;
		this.rows = layoutAtoms(this.buffer, this.contentWidth, visibleWidth);
		this.layoutKey = key;
	}
	render(width: number): string[] {
		if (width < 1) return [];
		this.renderedPadding = Math.min(this.getPaddingX(), Math.max(0, Math.floor((width - 1) / 2)));
		const bodyWidth = width - this.renderedPadding * 2;
		this.contentWidth = Math.max(1, bodyWidth - 1);
		this.updateRows();
		const caret = caretInRows(this.rows, this.buffer.getCursor());
		const maxRows = Math.max(5, Math.floor(this.tui.terminal.rows * 0.3));
		this.firstVisible = Math.max(0, Math.min(this.firstVisible, this.rows.length - maxRows));
		if (caret.row < this.firstVisible) this.firstVisible = caret.row;
		if (caret.row >= this.firstVisible + maxRows) this.firstVisible = caret.row - maxRows + 1;
		const visible = this.rows.slice(this.firstVisible, this.firstVisible + maxRows);
		this.visibleRows = visible.length;
		const showCursor = this.focused && this.terminalFocused;
		this.borderColor = text => this.palette().style(text, { fg: showCursor ? herdrPaneBorder : "dim" });
		const output = [this.renderTopBorder(width, this.firstVisible)];
		for (let index = 0; index < visible.length; index++) {
			const row = visible[index];
			let text = " ".repeat(this.renderedPadding);
			let columns = 0;
			for (const cell of row.cells) {
				let shown = cell.text;
				if (cell.atom?.expansion?.startsWith("/skill:") && this.known().has(cell.atom.expansion.slice(7))) shown = this.palette().style(shown, { fg: "customMessageLabel", bg: "customMessageBg", bold: true });
				if (showCursor && (cell.start === this.buffer.getCursor() || (bodyWidth === 1 && cell === row.cells.at(-1) && this.buffer.getCursor() === row.end && !row.softBreak))) shown = CURSOR_MARKER + this.palette().style(cell.text, { fg: this.palette().colors.customMessageBg, bg: this.palette().colors.muted });
				text += shown;
				columns += cell.columns;
			}
			if (showCursor && this.buffer.getCursor() === row.end && !row.softBreak && columns < bodyWidth) {
				text += CURSOR_MARKER + this.palette().style(" ", { fg: this.palette().colors.customMessageBg, bg: this.palette().colors.muted });
				columns++;
			}
			text += " ".repeat(Math.max(0, bodyWidth - columns) + this.renderedPadding);
			output.push(text);
		}
		output.push(this.renderBottomBorder(width, Math.max(0, this.rows.length - this.firstVisible - visible.length)));
		if (this.menu) for (const line of this.menu.render(bodyWidth)) output.push(" ".repeat(this.renderedPadding) + line + " ".repeat(this.renderedPadding));
		return showCursor ? output : output.map(line => this.palette().fg("dim", stripTerminalSequences(line)));
	}

	handleMouse(event: TuiMouseEvent): TuiMouseEventResult | undefined {
		if (this.menu && event.y >= this.visibleRows + 2) return this.menu.handleMouse({ ...event, x: event.x - this.renderedPadding, y: event.y - this.visibleRows - 2 });
		if (event.type !== "click" || event.button !== "left") return undefined;
		if (event.y > 0 && event.y <= this.visibleRows) {
			const row = this.rows[this.firstVisible + event.y - 1];
			if (row) this.buffer.setCursor(cursorInRow(row, Math.max(0, event.x - this.renderedPadding)));
			this.preferredColumn = undefined;
			this.historyPosition = -1;
			this.tui.requestRender();
		}
		return { handled: true, focus: true };
	}

	handleInput(data: string): void {
		if (isKeyRelease(data)) return;
		if (this.onExtensionShortcut?.(data)) return;
		const match = (key: Parameters<KeybindingsManager["matches"]>[1]): boolean => this.editorKeys.matches(data, key);
		if (match("app.clipboard.pasteImage")) { this.onPasteImage?.(); return; }
		if (this.bufferedPaste !== undefined || data.includes("\x1b[200~")) { this.paste(data); return; }
		if (this.menu) {
			if (match("tui.select.cancel") || match("app.interrupt")) { this.closeMenu(); this.tui.requestRender(); return; }
			if (match("tui.select.up") || match("tui.select.down") || match("tui.select.pageUp") || match("tui.select.pageDown")) { this.menu.handleInput(data); this.tui.requestRender(); return; }
			if (match("tui.input.tab") || match("tui.select.confirm")) { this.acceptCompletion(); return; }
		}
		if (match("app.interrupt")) { (this.onEscape ?? this.actionHandlers.get("app.interrupt"))?.(); return; }
		if (match("app.exit") && !this.getText()) { (this.onCtrlD ?? this.actionHandlers.get("app.exit"))?.(); return; }
		if (match("tui.editor.historyPrevious")) { this.browseHistory(-1); return; }
		if (match("tui.editor.historyNext")) { this.browseHistory(1); return; }
		for (const [action, handler] of this.actionHandlers) if (action !== "app.interrupt" && action !== "app.exit" && match(action)) {
			if (action === "app.message.followUp") {
				const canonical = this.getExpandedText();
				if (!this.beforeSubmit(canonical)) return;
				this.submittedDraft = { canonical, draft: this.getDraft() };
			}
			handler(); return;
		}
		if (match("tui.input.copy")) return;
		if (this.jumpDirection) {
			const direction = this.jumpDirection; this.jumpDirection = undefined;
			if (match("tui.editor.jumpForward") || match("tui.editor.jumpBackward")) return;
			const text = printable(data);
			if (text) {
				const cursor = this.buffer.getCursor();
				const segments = [...graphemes.segment(this.getText())].filter(segment => segment.segment.startsWith(text) && (direction === "forward" ? segment.index > cursor : segment.index < cursor));
				const target = direction === "forward" ? segments[0] : segments.at(-1);
				if (target) this.buffer.setCursor(target.index);
				this.changed(false); return;
			}
		}
		if (match("tui.editor.jumpForward") || match("tui.editor.jumpBackward")) { this.jumpDirection = match("tui.editor.jumpForward") ? "forward" : "backward"; return; }
		if (match("tui.input.tab")) { void this.complete(true); return; }
		const newline = match("tui.input.newLine") || data === "\n" || data === "\x1b\r" || data === "\x1b[13;2~";
		const backslash = this.buffer.getCursor() > this.lineStart() && this.getText()[this.buffer.getCursor() - 1] === "\\";
		if (newline) {
			if (backslash && !this.disableSubmit && matchesKey(data, "enter") && this.editorKeys.getKeys("tui.input.submit").some(key => key === "shift+enter" || key === "shift+return")) { this.buffer.deleteBackward(); this.submitCurrent(); }
			else { this.buffer.insertText("\n"); this.collapseRawSkills(); this.changed(); }
			return;
		}
		if (match("tui.input.submit")) {
			if (this.disableSubmit) return;
			if (backslash) { this.buffer.deleteBackward(); this.buffer.insertText("\n"); this.changed(); }
			else this.submitCurrent();
			return;
		}
		if (match("tui.editor.undo")) { this.buffer.undo(); this.changed(false); return; }
		if (match("tui.editor.yank")) { this.performYank(false); return; }
		if (match("tui.editor.yankPop")) { this.performYank(true); return; }
		const backward = match("tui.editor.deleteWordBackward") || match("tui.editor.deleteToLineStart");
		const forward = match("tui.editor.deleteWordForward") || match("tui.editor.deleteToLineEnd");
		if (backward || forward) {
			const cursor = this.buffer.getCursor();
			const target = match("tui.editor.deleteToLineStart") ? this.lineStart() : match("tui.editor.deleteToLineEnd") ? this.lineEnd() : this.wordTarget(backward ? -1 : 1);
			this.kill(Math.min(cursor, target), Math.max(cursor, target), backward ? "backward" : "forward"); return;
		}
		this.lastKill = undefined; this.yankSpan = undefined;
		if (match("tui.editor.cursorUp") || match("tui.editor.cursorDown")) { this.vertical(match("tui.editor.cursorUp") ? -1 : 1, true); return; }
		if (match("tui.editor.pageUp") || match("tui.editor.pageDown")) { this.vertical((match("tui.editor.pageUp") ? -1 : 1) * Math.max(5, Math.floor(this.tui.terminal.rows * 0.3)), false); return; }
		this.preferredColumn = undefined;
		if (match("tui.editor.cursorLeft")) this.buffer.moveLeft();
		else if (match("tui.editor.cursorRight")) this.buffer.moveRight();
		else if (match("tui.editor.cursorWordLeft")) this.buffer.setCursor(this.wordTarget(-1));
		else if (match("tui.editor.cursorWordRight")) this.buffer.setCursor(this.wordTarget(1));
		else if (match("tui.editor.cursorLineStart")) this.buffer.setCursor(this.lineStart());
		else if (match("tui.editor.cursorLineEnd")) this.buffer.setCursor(this.lineEnd());
		else if (match("tui.editor.deleteCharBackward")) this.buffer.deleteBackward();
		else if (match("tui.editor.deleteCharForward")) this.buffer.deleteForward();
		else if (match("tui.input.newLine")) this.buffer.insertText("\n");
		else {
			const text = printable(data);
			if (!text) return;
			this.buffer.insertText(text);
		}
		this.collapseRawSkills();
		this.historyPosition = -1;
		this.changed();
	}

	private submitCurrent(): void {
		const canonical = this.getExpandedText().trim();
		if (!this.beforeSubmit(canonical)) return;
		this.submittedDraft = { canonical, draft: this.getDraft() };
		this.setText("");
		this.onSubmit?.(canonical);
	}

	private collapseRawSkills(includeEnd = false): void {
		const text = this.getText();
		if (!allowsSkillTokens(text)) return;
		const pattern = includeEnd ? /(^|\s)\/skill:([^\s/]+(?:\/[^\s/]+)?)(?=\s|$)/g : /(^|\s)\/skill:([^\s/]+(?:\/[^\s/]+)?)(?=\s)/g;
		const matches = [...text.matchAll(pattern)].reverse();
		for (const match of matches) {
			if (!this.known().has(match[2])) continue;
			const start = match.index + match[1].length;
			this.buffer.collapseToAtom(start, match.index + match[0].length, ` ${match[2]}`, `/skill:${match[2]}`);
		}
	}

	private changed(suggest = true): void {
		if (allowsSkillTokens(this.getText())) {
			for (const span of this.buffer.getAtomSpans()) {
				const name = span.label.slice(2);
				if (!span.expansion && this.known().has(name)) this.buffer.registerAtom(span.label, `/skill:${name}`);
			}
		}
		this.layoutKey = "";
		this.onChange?.(this.getText());
		this.tui.requestRender();
		if (suggest) void this.complete(false); else this.closeMenu();
	}
	private closeMenu(): void { this.completionAbort?.abort(); this.completionAbort = undefined; this.menu = undefined; this.suggestions = undefined; this.forcedCompletion = false; }
	private async complete(force: boolean): Promise<void> {
		const text = this.getText(); const cursor = this.buffer.getCursor();
		const before = text.slice(0, cursor);
		const slash = before.trimStart().startsWith("/");
		const skill = /(?:^|\s)(\/skill:[^\s]*)$/.exec(before) ?? (!slash ? /(?:^|\s)(\/[^\s/]*)$/.exec(before) : null);
		const skillCompletion = Boolean(skill && allowsSkillTokens(text));
		const forced = force || (this.forcedCompletion && Boolean(this.menu) && /\S$/u.test(before));
		if (!forced && !skillCompletion && !slash && !this.completionTrigger.test(before)) {
			const visible = Boolean(this.menu);
			this.closeMenu();
			if (visible) this.tui.requestRender();
			return;
		}
		this.completionAbort?.abort();
		const abort = new AbortController(); this.completionAbort = abort;
		this.forcedCompletion = forced;
		let result: AutocompleteSuggestions | null = null;
		try {
			if (skillCompletion && skill) {
				const query = skill[1].startsWith("/skill:") ? skill[1].slice(7) : skill[1].slice(1);
				result = { prefix: skill[1], items: [...this.known()].filter(name => name.startsWith(query)).map(name => ({ value: `skill:${name}`, label: `/skill:${name}` })) };
			} else if (this.completionProvider) {
				const position = this.getCursor();
				result = await this.completionProvider.getSuggestions(this.getLines(), position.line, position.col, { signal: abort.signal, force: forced && !/^\/\S*$/.test(before.split("\n").at(-1)!) });
			}
			if (abort.signal.aborted) return;
			if (!result?.items.length) {
				const visible = Boolean(this.menu);
				this.closeMenu();
				if (visible) this.tui.requestRender();
				return;
			}
			this.suggestions = result;
			this.menu = new SelectList(result.items, this.getAutocompleteMaxVisible(), this.editorTheme.selectList);
			this.menu.onSelect = () => this.acceptCompletion();
			if (force && result.items.length === 1) this.acceptCompletion(); else this.tui.requestRender();
		} catch (error) {
			if (abort.signal.aborted) return;
			this.closeMenu();
			this.reportError(new Error("Prompt autocomplete failed", { cause: error }));
		}
	}
	private acceptCompletion(): void {
		const item = this.menu?.getSelectedItem(); const suggestions = this.suggestions;
		if (!item || !suggestions) return;
		const name = item.value.replace(/^\/?skill:/, "");
		const cursor = this.buffer.getCursor();
		if (/^\/?skill:/.test(item.value) && this.known().has(name)) {
			const label = ` ${name}`;
			this.buffer.registerAtom(label, `/skill:${name}`);
			this.buffer.replaceRange(cursor - suggestions.prefix.length, cursor, `${label} `);
		} else {
			if (!this.completionProvider) throw new Error("Autocomplete selection has no provider");
			const position = this.getCursor();
			const result = this.completionProvider.applyCompletion(this.getLines(), position.line, position.col, item, suggestions.prefix);
			this.applyText(result.lines.join("\n"));
			this.buffer.setCursor(result.lines.slice(0, result.cursorLine).reduce((sum, line) => sum + line.length + 1, 0) + result.cursorCol);
		}
		this.closeMenu(); this.changed(false);
	}
	private applyText(text: string): void {
		const before = [...graphemes.segment(this.getText())]; const after = [...graphemes.segment(text)];
		let prefix = 0; let suffix = 0;
		while (prefix < before.length && prefix < after.length && before[prefix].segment === after[prefix].segment) prefix++;
		while (suffix < before.length - prefix && suffix < after.length - prefix && before[before.length - 1 - suffix].segment === after[after.length - 1 - suffix].segment) suffix++;
		const start = before[prefix]?.index ?? this.getText().length;
		const end = before[before.length - suffix]?.index ?? this.getText().length;
		const newStart = after[prefix]?.index ?? text.length;
		const newEnd = after[after.length - suffix]?.index ?? text.length;
		this.buffer.replaceRange(start, end, text.slice(newStart, newEnd));
	}
	private paste(data: string): void {
		const start = data.indexOf("\x1b[200~");
		if (start >= 0 && this.bufferedPaste === undefined) { if (start) this.handleInput(data.slice(0, start)); this.bufferedPaste = ""; data = data.slice(start + 6); }
		this.bufferedPaste = (this.bufferedPaste ?? "") + data;
		const end = this.bufferedPaste.indexOf("\x1b[201~"); if (end < 0) return;
		const body = this.bufferedPaste.slice(0, end); const remaining = this.bufferedPaste.slice(end + 6); this.bufferedPaste = undefined;
		if (body.length > 1000 || body.split("\n").length > 10) this.buffer.insertAtom(`[Paste #${++this.pasteNumber}]`, body);
		else { this.buffer.insertText(body); this.collapseRawSkills(true); }
		this.changed(false); if (remaining) this.handleInput(remaining);
	}
	private lineStart(): number { const cursor = this.buffer.getCursor(); return cursor ? this.getText().lastIndexOf("\n", cursor - 1) + 1 : 0; }
	private lineEnd(): number { const end = this.getText().indexOf("\n", this.buffer.getCursor()); return end < 0 ? this.getText().length : end; }
	private wordTarget(direction: -1 | 1): number {
		const cursor = this.buffer.getCursor();
		const atom = this.buffer.atomAt(direction < 0 ? cursor - 1 : cursor);
		if (atom) return direction < 0 ? atom.start : atom.end;
		const segments = [...graphemes.segment(this.getText())];
		const candidates = direction < 0 ? segments.filter(segment => segment.index < cursor).reverse() : segments.filter(segment => segment.index >= cursor);
		let target = cursor; let category: string | undefined;
		for (const segment of candidates) {
			if (segment.segment === "\n") return target === cursor ? (direction < 0 ? segment.index : segment.index + 1) : target;
			const kind = /^\s+$/u.test(segment.segment) ? "space" : /^[\p{L}\p{N}_]/u.test(segment.segment) ? "word" : "punctuation";
			if (category && category !== kind) break;
			if (kind !== "space") category = kind;
			target = direction < 0 ? segment.index : segment.index + segment.segment.length;
			if (this.buffer.atomAt(direction < 0 ? target - 1 : target)) break;
		}
		return target;
	}
	private vertical(delta: number, browse: boolean): void {
		this.updateRows(); const caret = caretInRows(this.rows, this.buffer.getCursor());
		if (browse && delta < 0 && caret.row === 0) {
			if (!this.getText() || this.historyPosition >= 0 || this.getCursor().col === 0) this.browseHistory(delta);
			else { this.buffer.setCursor(this.lineStart()); this.changed(false); }
			return;
		}
		if (browse && delta > 0 && caret.row === this.rows.length - 1) {
			if (this.historyPosition >= 0) this.browseHistory(delta);
			else { this.buffer.setCursor(this.lineEnd()); this.changed(false); }
			return;
		}
		this.preferredColumn ??= caret.column;
		this.buffer.setCursor(cursorInRow(this.rows[Math.max(0, Math.min(this.rows.length - 1, caret.row + delta))], this.preferredColumn));
		this.changed(false);
	}
	private browseHistory(direction: number): void {
		if (!this.promptHistory.length) return;
		if (this.historyPosition < 0 && direction < 0) this.savedDraft = this.getDraft();
		const next = Math.max(-1, Math.min(this.promptHistory.length - 1, this.historyPosition - Math.sign(direction)));
		if (next === this.historyPosition) return;
		const draft = next < 0 ? this.savedDraft : this.promptHistory[next].draft;
		this.historyPosition = next;
		if (draft) this.restoreDraft(draft);
		this.preferredColumn = undefined;
	}
	private kill(start: number, end: number, direction: "backward" | "forward"): void {
		if (start === end && direction === "backward" && start > 0) start--;
		if (start === end && direction === "forward" && end < this.getText().length) end++;
		if (start === end) return;
		const range = this.buffer.expandRange(start, end);
		const text = this.getText().slice(range.start, range.end);
		const draft: SkillDraft = { text, cursor: text.length, atoms: this.buffer.getRegisteredAtoms() };
		if (this.lastKill === direction && this.kills.length) this.kills[0].text = direction === "backward" ? text + this.kills[0].text : this.kills[0].text + text;
		else this.kills.unshift(draft);
		this.kills.length = Math.min(this.kills.length, 100);
		this.buffer.replaceRange(range.start, range.end, "");
		this.lastKill = direction; this.yankSpan = undefined; this.changed(false);
	}
	private performYank(pop: boolean): void {
		if (!this.kills.length || (pop && !this.yankSpan)) return;
		const index = pop ? (this.yankSpan!.index + 1) % this.kills.length : 0;
		const draft = this.kills[index];
		for (const [label, expansion] of draft.atoms) this.buffer.registerAtom(label, expansion);
		const start = pop ? this.yankSpan!.start : this.buffer.getCursor(); const end = pop ? this.yankSpan!.end : start;
		this.buffer.replaceRange(start, end, draft.text);
		this.yankSpan = { start, end: start + draft.text.length, index }; this.lastKill = undefined; this.changed(false);
	}
}
