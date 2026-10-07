import type { ExtensionAPI, KeybindingsManager, Theme } from "@earendil-works/pi-coding-agent";
import { CustomEditor } from "@earendil-works/pi-coding-agent";
import type { EditorTheme, TUI, TuiMouseEvent, TuiMouseEventResult } from "@earendil-works/pi-tui";
import { visibleWidth } from "@earendil-works/pi-tui";

interface ChipPosition {
	padding: number;
	end: number;
	delta: number;
	rawEnd: number;
}

export function expandSkillChip(text: string, known: ReadonlySet<string>): string {
	return text.replace(/^ ([^\s]+)(?=\s|$)/, (token, name: string) => known.has(name) ? `/skill:${name}` : token);
}

export class SkillInputEditor extends CustomEditor {
	private chip?: ChipPosition;

	constructor(
		tui: TUI,
		theme: EditorTheme,
		keybindings: KeybindingsManager,
		private knownSkills: () => ReadonlySet<string>,
		private chipTheme: () => Theme,
	) {
		super(tui, theme, keybindings, { embedWorkingStatus: true });
	}

	render(width: number): string[] {
		const lines = super.render(width);
		this.chip = undefined;
		const raw = this.getText();
		const cursor = this.getCursor();
		const match = /^\/skill:([^\s]+)(?=\s|$)/.exec(raw);
		const padding = Math.min(this.getPaddingX(), Math.max(0, Math.floor((width - 1) / 2)));
		if (!match || !this.knownSkills().has(match[1]) || raw.includes("\n") || cursor.line !== 0 || cursor.col < match[0].length || visibleWidth(raw) + 1 > width - padding * 2) return lines;
		if (!lines[1]?.includes(match[0])) return lines;
		const label = ` ${match[1]}`;
		const delta = visibleWidth(match[0]) - visibleWidth(label);
		const styled = this.chipTheme().style(label, { fg: "customMessageLabel", bg: "customMessageBg", bold: true });
		lines[1] = lines[1].replace(match[0], styled) + " ".repeat(delta);
		this.chip = { padding, end: visibleWidth(label), delta, rawEnd: visibleWidth(match[0]) };
		return lines;
	}

	handleMouse(event: TuiMouseEvent): TuiMouseEventResult | undefined {
		if (this.chip && event.type === "click" && event.button === "left" && event.y === 1) {
			const chip = this.chip;
			return super.handleMouse({ ...event, x: event.x < chip.padding + chip.end ? chip.padding + chip.rawEnd : event.x + chip.delta });
		}
		return super.handleMouse(event);
	}
}

export function registerSkillInput(pi: ExtensionAPI): void {
	let known = new Set<string>();
	pi.on("session_start", (_event, ctx) => {
		known = new Set(pi.getCommands().filter(command => command.source === "skill").map(command => command.name.replace(/^skill:/, "")));
		if (ctx.mode !== "tui") return;
		const draft = ctx.ui.getEditorText();
		ctx.ui.setEditorComponent((tui, theme, keys) => new SkillInputEditor(tui, theme, keys, () => known, () => ctx.ui.theme));
		ctx.ui.setEditorText(draft);
	});
	pi.on("input", (event, ctx) => {
		if (ctx.mode !== "tui") return;
		const text = expandSkillChip(event.text, known);
		if (text !== event.text) return { action: "transform", text };
	});
	pi.on("session_shutdown", (event, ctx) => {
		if (event.reason !== "reload" || ctx.mode !== "tui") return;
		const draft = ctx.ui.getEditorText();
		ctx.ui.setEditorComponent(undefined);
		ctx.ui.setEditorText(draft);
	});
}
