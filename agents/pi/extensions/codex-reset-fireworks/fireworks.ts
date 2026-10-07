import {
	type Component,
	matchesKey,
	truncateToWidth,
	visibleWidth,
} from "@earendil-works/pi-tui";
import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";

const FRAME_INTERVAL_MS = 85;
const FRAME_COUNT = 34;
const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

const FIREWORK_THEME_COLORS = {
	cyan: "mdLink",
	dim: "dim",
	gold: "warning",
	green: "success",
	pink: "accent",
	violet: "thinkingXhigh",
	white: "text",
} as const satisfies Record<string, ThemeColor>;

type FireworkColor = keyof typeof FIREWORK_THEME_COLORS;

export interface CodexResetUsageSnapshot {
	
	observedAt?: number;
	
	sevenDay?: { percent: number; resetsAt?: number; tier?: string; plan?: string };
	savedResets?: number;
}

export type CodexResetFireworksEvent =
	| { kind: "unscheduled-weekly-reset" }
	| { kind: "saved-reset-banked"; added: number; available: number };

interface CanvasCell {
	glyph: string;
	color: FireworkColor;
	priority: number;
}

interface FireworkBurst {
	x: number;
	y: number;
	start: number;
	color: FireworkColor;
}

const BURSTS: readonly FireworkBurst[] = [
	{ x: 0.17, y: 0.46, start: 5, color: "pink" },
	{ x: 0.48, y: 0.2, start: 9, color: "cyan" },
	{ x: 0.78, y: 0.42, start: 13, color: "gold" },
	{ x: 0.31, y: 0.24, start: 17, color: "violet" },
	{ x: 0.65, y: 0.28, start: 21, color: "green" },
	{ x: 0.88, y: 0.18, start: 25, color: "pink" },
];

export function detectCodexResetFireworks(
	previous: CodexResetUsageSnapshot,
	current: CodexResetUsageSnapshot,
): CodexResetFireworksEvent | undefined {
	const previousSavedResets = previous.savedResets;
	const currentSavedResets = current.savedResets;
	if (previousSavedResets !== undefined) {
		if (currentSavedResets === undefined) {
			if (previousSavedResets > 0) return undefined;
		} else {
			if (currentSavedResets > previousSavedResets) {
				return {
					kind: "saved-reset-banked",
					added: currentSavedResets - previousSavedResets,
					available: currentSavedResets,
				};
			}
			if (currentSavedResets < previousSavedResets) return undefined;
		}
	}

	if (!previous.sevenDay || !current.sevenDay) return undefined;
	if (previous.sevenDay.tier !== current.sevenDay.tier || previous.sevenDay.plan !== current.sevenDay.plan) {
		return undefined;
	}
	const previousWeeklyPercent = Math.round(Math.max(0, Math.min(100, previous.sevenDay.percent)));
	const currentWeeklyPercent = Math.round(Math.max(0, Math.min(100, current.sevenDay.percent)));
	if (previousWeeklyPercent === 0 || currentWeeklyPercent >= previousWeeklyPercent) return undefined;

	const scheduledResetAt = previous.sevenDay.resetsAt;
	const nextResetAt = current.sevenDay.resetsAt;
	if (
		scheduledResetAt === undefined ||
		!Number.isFinite(scheduledResetAt) ||
		nextResetAt === undefined ||
		!Number.isFinite(nextResetAt) ||
		nextResetAt <= scheduledResetAt ||
		typeof current.observedAt !== "number" ||
		!Number.isFinite(current.observedAt) ||
		current.observedAt >= scheduledResetAt
	) {
		return undefined;
	}
	return { kind: "unscheduled-weekly-reset" };
}

function setCell(
	canvas: Array<Array<CanvasCell | undefined>>,
	x: number,
	y: number,
	glyph: string,
	color: FireworkColor,
	priority: number,
): void {
	const row = canvas[y];
	if (!row || x < 0 || x >= row.length) return;
	const current = row[x];
	if (!current || priority >= current.priority) row[x] = { glyph, color, priority };
}

function drawText(
	canvas: Array<Array<CanvasCell | undefined>>,
	x: number,
	y: number,
	text: string,
	color: FireworkColor,
	priority: number,
): void {
	let column = x;
	for (const { segment } of segmenter.segment(text)) {
		const width = visibleWidth(segment);
		if (width <= 0) continue;
		setCell(canvas, column, y, segment, color, priority);
		for (let continuation = 1; continuation < width; continuation++) {
			setCell(canvas, column + continuation, y, "", color, priority);
		}
		column += width;
	}
}

function drawBanner(
	canvas: Array<Array<CanvasCell | undefined>>,
	left: number,
	artWidth: number,
	height: number,
	event: CodexResetFireworksEvent,
): void {
	if (height < 3 || artWidth < 8) return;
	const panelWidth = Math.min(62, artWidth);
	const panelLeft = left + Math.floor((artWidth - panelWidth) / 2);
	const top = height - 3;
	const innerWidth = panelWidth - 2;
	const titleText =
		event.kind === "unscheduled-weekly-reset" ? " O P E N A I   R E S E T " : " S A V E D   R E S E T ";
	const subtitleText =
		event.kind === "unscheduled-weekly-reset"
			? "Weekly usage cleared early · ESC to return"
			: event.added === 1
				? `New reset banked · ${event.available} available · ESC to return`
				: `${event.added} resets banked · ${event.available} available · ESC to return`;
	const title = truncateToWidth(titleText, innerWidth, "");
	const subtitle = truncateToWidth(subtitleText, innerWidth, "");
	const titleOffset = Math.floor((innerWidth - visibleWidth(title)) / 2);
	const subtitleOffset = Math.floor((innerWidth - visibleWidth(subtitle)) / 2);

	drawText(canvas, panelLeft, top, `╭${"─".repeat(innerWidth)}╮`, "violet", 20);
	drawText(canvas, panelLeft + 1 + titleOffset, top, title, "gold", 21);
	drawText(canvas, panelLeft, top + 1, `│${" ".repeat(innerWidth)}│`, "violet", 20);
	drawText(canvas, panelLeft + 1 + subtitleOffset, top + 1, subtitle, "cyan", 21);
	drawText(canvas, panelLeft, top + 2, `╰${"─".repeat(innerWidth)}╯`, "violet", 20);
}

function drawStars(
	canvas: Array<Array<CanvasCell | undefined>>,
	left: number,
	artWidth: number,
	skyHeight: number,
	frame: number,
): void {
	if (skyHeight <= 0) return;
	const count = Math.min(26, Math.max(5, Math.floor(artWidth / 3)));
	for (let index = 0; index < count; index++) {
		const x = left + ((index * 37 + 11) % artWidth);
		const y = (index * 7 + 2) % skyHeight;
		const bright = (index + Math.floor(frame / 3)) % 5 === 0;
		setCell(canvas, x, y, bright ? "+" : ".", bright ? "white" : "dim", bright ? 2 : 1);
	}
}

function drawBurst(
	canvas: Array<Array<CanvasCell | undefined>>,
	burst: FireworkBurst,
	left: number,
	artWidth: number,
	skyHeight: number,
	frame: number,
): void {
	if (skyHeight <= 1) return;
	const centerX = left + Math.round((artWidth - 1) * burst.x);
	const centerY = Math.max(0, Math.min(skyHeight - 2, Math.round((skyHeight - 1) * burst.y)));
	const age = frame - burst.start;

	if (age >= -6 && age < 0) {
		const progress = (age + 6) / 6;
		const y = skyHeight - 1 - Math.round(progress * (skyHeight - 1 - centerY));
		setCell(canvas, centerX, y, "^", "white", 8);
		setCell(canvas, centerX, y + 1, "|", burst.color, 7);
		setCell(canvas, centerX, y + 2, ".", "gold", 6);
		return;
	}
	if (age < 0 || age > 8) return;

	const radius = age === 0 ? 0 : 0.8 + age * 0.92;
	const gravity = Math.floor((age * age) / 22);
	const glyphs = ["@", "*", "*", "+", "o", "o", ".", ".", "."] as const;
	const particleColor: FireworkColor = age <= 5 ? burst.color : age <= 7 ? "gold" : "dim";

	for (let particle = 0; particle < 20; particle++) {
		const angle = (particle / 20) * Math.PI * 2 + burst.start * 0.17;
		const x = centerX + Math.round(Math.cos(angle) * radius * 1.75);
		const y = centerY + Math.round(Math.sin(angle) * radius * 0.58 + gravity);
		setCell(canvas, x, y, glyphs[age], particleColor, 10);
		if (age >= 2 && age <= 6) {
			const trailRadius = Math.max(0, radius - 1.4);
			const trailX = centerX + Math.round(Math.cos(angle) * trailRadius * 1.75);
			const trailY = centerY + Math.round(Math.sin(angle) * trailRadius * 0.58 + gravity);
			setCell(canvas, trailX, trailY, ".", "dim", 5);
		}
	}
	if (age <= 2) setCell(canvas, centerX, centerY, age === 0 ? "@" : "+", "white", 12);
}

function renderCanvas(canvas: Array<Array<CanvasCell | undefined>>, theme: Theme): string[] {
	return canvas.map(row => {
		let output = "";
		let run = "";
		let runColor: FireworkColor | undefined;
		for (const cell of row) {
			if (cell && cell.color !== runColor) {
				if (run) output += runColor ? theme.fg(FIREWORK_THEME_COLORS[runColor], run) : run;
				run = "";
				runColor = cell.color;
			}
			run += cell?.glyph ?? " ";
		}
		if (run) output += runColor ? theme.fg(FIREWORK_THEME_COLORS[runColor], run) : run;
		return output;
	});
}

export function renderCodexResetFireworks(
	width: number,
	height: number,
	frame: number,
	event: CodexResetFireworksEvent,
	theme: Theme,
): string[] {
	const safeWidth = Math.max(1, Math.floor(width));
	const safeHeight = Math.max(1, Math.floor(height));
	const artWidth = Math.min(96, safeWidth);
	const left = Math.floor((safeWidth - artWidth) / 2);
	const skyHeight = Math.max(0, safeHeight - 3);
	const canvas = Array.from({ length: safeHeight }, () => new Array<CanvasCell | undefined>(safeWidth));

	drawStars(canvas, left, artWidth, skyHeight, frame);
	for (const burst of BURSTS) drawBurst(canvas, burst, left, artWidth, skyHeight, frame);
	drawBanner(canvas, left, artWidth, safeHeight, event);
	return renderCanvas(canvas, theme);
}

export class CodexResetFireworksComponent implements Component {
	#timer: ReturnType<typeof setInterval> | undefined;
	#frame = 0;
	#disposed = false;

	constructor(
		readonly host: { requestRender(): void; terminal: { rows: number } },
		readonly theme: Theme,
		readonly event: CodexResetFireworksEvent,
		readonly done: () => void,
	) {
		this.#timer = setInterval(() => {
			this.#frame = (this.#frame + 1) % FRAME_COUNT;
			this.host.requestRender();
		}, FRAME_INTERVAL_MS);
		this.#timer.unref();
	}

	dispose(): void {
		if (this.#disposed) return;
		this.#disposed = true;
		clearInterval(this.#timer);
		this.#timer = undefined;
	}

	close(): void {
		if (this.#disposed) return;
		this.dispose();
		this.done();
	}

	handleInput(data: string): void {
		if (matchesKey(data, "escape")) this.close();
	}

	invalidate(): void {}

	render(width: number): string[] {
		const height = Math.max(1, Math.floor(this.host.terminal.rows * 0.33));
		return renderCodexResetFireworks(width, height, this.#frame, this.event, this.theme);
	}
}
