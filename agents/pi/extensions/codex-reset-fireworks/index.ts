import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	CodexResetFireworksComponent,
	detectCodexResetFireworks,
	type CodexResetFireworksEvent,
	type CodexResetUsageSnapshot,
} from "./fireworks";

interface QuotaReport {
	account: string;
	observedAt: number;
	body: {
		plan_type?: string;
		rate_limit?: {
			primary_window?: QuotaWindow | null;
			secondary_window?: QuotaWindow | null;
		};
		rate_limit_reset_credits?: { available_count?: number };
	};
}

interface QuotaWindow {
	used_percent: number;
	reset_at: number;
	limit_window_seconds: number;
}

export function quotaSnapshot(report: QuotaReport): CodexResetUsageSnapshot {
	const windows = [report.body.rate_limit?.primary_window, report.body.rate_limit?.secondary_window];
	const weekly = windows.find(window => window?.limit_window_seconds === 604800);
	const count = report.body.rate_limit_reset_credits?.available_count;
	return {
		observedAt: report.observedAt,
		sevenDay: weekly ? {
			percent: weekly.used_percent,
			resetsAt: weekly.reset_at * 1000,
			plan: report.body.plan_type,
		} : undefined,
		savedResets: typeof count === "number" && Number.isFinite(count) ? Math.max(0, Math.trunc(count)) : undefined,
	};
}

export default function codexResetFireworks(pi: ExtensionAPI) {
	let context: ExtensionContext | undefined;
	let previous: { account: string; snapshot: CodexResetUsageSnapshot } | undefined;
	let active: { close(): void } | undefined;

	const show = async (event: CodexResetFireworksEvent) => {
		const ctx = context;
		if (!ctx || ctx.mode !== "tui" || active) return;
		const interaction = { close() {} };
		active = interaction;
		try {
			await ctx.ui.custom<void>((tui, theme, _keys, done) => {
				const component = new CodexResetFireworksComponent(tui, theme, event, () => done());
				interaction.close = () => component.close();
				return component;
			}, {
				overlay: true,
				overlayOptions: { anchor: "top-center", width: "100%", maxHeight: "33%", margin: 0 },
			});
		} catch (error) {
			ctx.ui.notify(`Codex fireworks failed: ${error instanceof Error ? error.message : String(error)}`, "error");
		} finally {
			if (active === interaction) active = undefined;
		}
	};

	const onQuota = (report: QuotaReport) => {
		if (!context) return;
		const snapshot = quotaSnapshot(report);
		const event = previous?.account === report.account
			? detectCodexResetFireworks(previous.snapshot, snapshot) : undefined;
		previous = { account: report.account, snapshot };
		if (event) void show(event);
	};

	const unsubscribe = pi.events.on("codex-quota-report", data => onQuota(data as QuotaReport));
	pi.on("session_start", (_event, ctx) => {
		active?.close();
		previous = undefined;
		context = ctx.mode === "tui" ? ctx : undefined;
	});
	pi.on("session_shutdown", () => {
		context = undefined;
		previous = undefined;
		active?.close();
		unsubscribe();
	});
	pi.registerCommand("fireworks", {
		description: "Preview OMP's Codex quota-reset fireworks (Esc to dismiss)",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("Fireworks require Pi's interactive terminal", "error");
				return;
			}
			context = ctx;
			await show({ kind: "unscheduled-weekly-reset" });
		},
	});
}
