import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const DIM = "\x1b[2m";
const DIM_OFF = "\x1b[22m";
const RESET = "\x1b[0m";
const GRAY = "\x1b[90m";
const FG_DEFAULT = "\x1b[39m";

const EFFORT_COLORS: Record<string, string> = {
	minimal: "\x1b[90m",
	low: "\x1b[90m",
	medium: "\x1b[94m",
	high: "\x1b[92m",
	xhigh: "\x1b[93m",
	max: "\x1b[91m",
	ultracode: "\x1b[95m",
};

const QUOTA_REFRESH_MS = 5 * 60_000;

interface UsageWindow {
	id?: string;
	resetsAt?: number;
}

interface UsageLimit {
	scope?: { modelId?: string };
	window?: UsageWindow;
	amount?: { usedFraction?: number; used?: number; limit?: number };
}

interface UsageReport {
	provider: string;
	limits: UsageLimit[];
}

interface AuthStorageLike {
	usage: { reports(options?: { signal?: AbortSignal }): Promise<UsageReport[] | null> };
	oauth: { identity(provider: string): { email?: string } | undefined };
}

interface StatusContext {
	cwd: string;
	model?: { provider?: string; id?: string };
	ui: {
		setStatus(key: string, text: string | undefined): void;
		setWidget(key: string, content: string[] | undefined, options?: { placement?: string }): void;
	};
	getContextUsage(): { tokens: number; contextWindow: number; percent: number } | undefined;
	modelRegistry?: { authStorage?: AuthStorageLike };
	setInterval(fn: () => void, ms: number): unknown;
}

function formatTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
	return `${n}`;
}

function usedFraction(limit: UsageLimit): number | undefined {
	const amount = limit.amount;
	if (!amount) return undefined;
	if (amount.usedFraction !== undefined) return amount.usedFraction;
	if (amount.used !== undefined && amount.limit !== undefined && amount.limit > 0) {
		return amount.used / amount.limit;
	}
	return undefined;
}

function pickWindowLimit(limits: UsageLimit[], windowId: string, modelId: string | undefined): UsageLimit | undefined {
	const candidates = limits.filter(limit => limit.window?.id === windowId && usedFraction(limit) !== undefined);
	if (candidates.length === 0) return undefined;
	return (
		candidates.find(limit => modelId !== undefined && limit.scope?.modelId === modelId) ??
		candidates.find(limit => !limit.scope?.modelId) ??
		candidates[0]
	);
}

function quotaText(fraction: number, resetsAt: number | undefined): string {
	const pct = Math.round(fraction * 100);
	const color = pct >= 90 ? "\x1b[31m" : pct >= 70 ? "\x1b[33m" : "\x1b[92m";
	const pctText = `${color}${pct}%${RESET}`;

	let countdown = "";
	if (resetsAt !== undefined) {
		const seconds = Math.floor((resetsAt - Date.now()) / 1000);
		if (seconds > 0) {
			const d = Math.floor(seconds / 86400);
			const h = Math.floor((seconds % 86400) / 3600);
			const m = Math.floor((seconds % 3600) / 60);
			const text = d > 0 ? `${d}d${h}h` : h > 0 ? `${h}h${m}m` : m > 0 ? `${m}m` : "<1m";
			countdown = `${DIM}-${text}${DIM_OFF}`;
		}
	}
	return `${pctText}${countdown}`;
}

function truncateForDisplay(line: string, columns: number): string {
	const budget = Math.max(8, columns - 3);
	let out = "";
	let width = 0;
	let state: "none" | "esc" | "csi" = "none";
	for (const ch of line) {
		if (state === "esc") {
			out += ch;
			state = ch === "[" ? "csi" : ch >= "@" && ch <= "~" ? "none" : "esc";
			continue;
		}
		if (state === "csi") {
			out += ch;
			if (ch >= "@" && ch <= "~") state = "none";
			continue;
		}
		if (ch === "\x1b") {
			state = "esc";
			out += ch;
			continue;
		}
		if (width >= budget) return `${out}${RESET}…`;
		out += ch;
		width++;
	}
	return out;
}

export default function ccStatusLine(pi: ExtensionAPI) {
	let cachedReports: UsageReport[] | null = null;
	let lastFetch = 0;
	let lastCtx: StatusContext | undefined;

	const update = async (ctx: StatusContext) => {
		lastCtx = ctx;
		const parts: string[] = [];

		const usage = ctx.getContextUsage();
		if (usage) {
			const level = pi.getThinkingLevel();
			const effortColor = level ? EFFORT_COLORS[level] : undefined;
			const context = `${formatTokens(usage.tokens)} (${Math.round(usage.percent)}%)`;
			parts.push(effortColor ? `${effortColor}${context}${RESET}` : context);
		}

		const folder = ctx.cwd.split(/[\\/]/).filter(Boolean).pop() ?? "";
		if (folder) parts.push(`${GRAY}${folder}${FG_DEFAULT}`);

		const auth = ctx.modelRegistry?.authStorage;
		const provider = ctx.model?.provider;
		if (auth && provider) {
			const now = Date.now();
			if (now - lastFetch > QUOTA_REFRESH_MS) {
				lastFetch = now;
				cachedReports = await auth.usage.reports().catch(() => null);
			}
			const report = cachedReports?.find(r => r.provider === provider);
			if (report) {
				const fiveHour = pickWindowLimit(report.limits, "5h", ctx.model?.id);
				const sevenDay =
					pickWindowLimit(report.limits, "7d", ctx.model?.id) ??
					pickWindowLimit(report.limits, "1w", ctx.model?.id);
				if (fiveHour) parts.push(quotaText(usedFraction(fiveHour) ?? 0, fiveHour.window?.resetsAt));
				if (sevenDay) parts.push(quotaText(usedFraction(sevenDay) ?? 0, sevenDay.window?.resetsAt));
			}
			const email = auth.oauth.identity(provider)?.email;
			if (email) parts.push(`${GRAY}${email}${FG_DEFAULT}`);
		}

		const line = ` ${parts.join(" · ")}`;
		const cols = process.stdout.columns ?? 120;
		const truncated = truncateForDisplay(line, cols);
		ctx.ui.setWidget("cc", parts.length > 0 ? [truncated] : undefined, { placement: "belowEditor" });
	};

	pi.on("session_start", (_event, ctx) => {
		void update(ctx);
		const timerCtx = ctx as unknown as StatusContext;
		timerCtx.setInterval(() => void update(timerCtx), 60_000);
	});
	pi.on("turn_end", (_event, ctx) => void update(ctx));
	process.stdout.on("resize", () => {
		if (lastCtx) void update(lastCtx);
	});
}
