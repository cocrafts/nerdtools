import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { readStoredCredential } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const RESET = "\x1b[0m";
const GRAY = "\x1b[90m";
const FG_DEFAULT = "\x1b[39m";

const EFFORT_COLORS: Record<string, string> = {
	minimal: "\x1b[90m",
	low: "\x1b[2m",
	medium: "\x1b[39m",
	high: "\x1b[94m",
	xhigh: "\x1b[93m",
	max: "\x1b[91m",
};

function formatTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
	return `${n}`;
}

interface QuotaWindow {
	used_percent: number;
	reset_at: number;
	limit_window_seconds: number;
}

function parseQuotaWindows(body: unknown): QuotaWindow[] {
	const rate = (body as { rate_limit?: { primary_window?: QuotaWindow | null; secondary_window?: QuotaWindow | null } })?.rate_limit;
	if (!rate) throw new Error("Codex quota response is missing rate_limit");
	const windows = [rate.primary_window, rate.secondary_window].filter((window): window is QuotaWindow => window != null);
	for (const window of windows) {
		if (!Number.isFinite(window.used_percent) || !Number.isFinite(window.reset_at) || !Number.isFinite(window.limit_window_seconds)) {
			throw new Error("Codex quota response has an invalid rate-limit window");
		}
	}
	if (windows.length === 0) throw new Error("Codex quota response has no rate-limit windows");
	return windows.sort((a, b) => a.limit_window_seconds - b.limit_window_seconds);
}

function quotaLabel(window: QuotaWindow): string {
	const pct = Math.round(window.used_percent);
	const color = pct >= 90 ? "\x1b[91m" : pct >= 70 ? "\x1b[93m" : "\x1b[92m";
	const seconds = Math.max(0, Math.floor(window.reset_at - Date.now() / 1000));
	const days = Math.floor(seconds / 86400);
	const hours = Math.floor(seconds % 86400 / 3600);
	const minutes = Math.floor(seconds % 3600 / 60);
	const countdown = days > 0 ? `${days}d${hours}h` : hours > 0 ? `${hours}h${minutes}m` : minutes > 0 ? `${minutes}m` : seconds > 0 ? "<1m" : "reset due";
	return `${color}${pct}%${RESET}\x1b[2m-${countdown}\x1b[22m`;
}

const QUOTA_POLL_MS = 60_000;
const QUOTA_POLL_AFTER_FAILURE_MS = 5 * 60_000;
const QUOTA_TIMER_SLACK_MS = 5_000;

function codexCliAuth(): { access: string; accountId: string } {
	const tokens = JSON.parse(readFileSync(join(homedir(), ".codex", "auth.json"), "utf8"))?.tokens;
	if (typeof tokens?.access_token !== "string" || typeof tokens?.account_id !== "string") {
		throw new Error("ChatGPT quota needs a Codex CLI sign-in (~/.codex/auth.json): run `codex login`");
	}
	return { access: tokens.access_token, accountId: tokens.account_id };
}

function quotaViaCodexCliRefreshingItsToken(signal: AbortSignal): Promise<QuotaWindow[]> {
	return new Promise((resolve, reject) => {
		const server = spawn("codex", ["app-server"], { stdio: ["pipe", "pipe", "ignore"], signal, timeout: 30_000 });
		let buffered = "";
		server.on("error", reject);
		server.on("exit", () => reject(new Error("codex app-server exited before reporting rate limits")));
		server.stdout.on("data", (chunk) => {
			buffered += chunk;
			for (let end = buffered.indexOf("\n"); end >= 0; end = buffered.indexOf("\n")) {
				const message = JSON.parse(buffered.slice(0, end));
				buffered = buffered.slice(end + 1);
				if (message.id === 1) {
					server.stdin.write('{"method":"initialized","params":{}}\n{"id":2,"method":"account/rateLimits/read","params":{}}\n');
				} else if (message.id === 2) {
					server.kill();
					const limits = message.result?.rateLimits;
					if (!limits) return reject(new Error(`codex app-server rate limits: ${JSON.stringify(message.error ?? message)}`));
					resolve(parseQuotaWindows({
						rate_limit: Object.fromEntries([["primary_window", limits.primary], ["secondary_window", limits.secondary]].map(([key, w]) => [
							key, w && { used_percent: w.usedPercent, reset_at: w.resetsAt, limit_window_seconds: w.windowDurationMins * 60 },
						])),
					}));
				}
			}
		});
		server.stdin.write('{"id":1,"method":"initialize","params":{"clientInfo":{"name":"pi-statusline","version":"1"}}}\n');
	});
}

function providerIdentity(provider: string): string | undefined {
	const credential = readStoredCredential(provider);
	if (credential?.type !== "oauth") return undefined;
	if (typeof credential.email === "string" && credential.email.length > 0) return credential.email;
	if (provider === "openai-codex" && typeof credential.access === "string") {
		try {
			const payload = JSON.parse(Buffer.from(credential.access.split(".")[1], "base64url").toString());
			const email = payload["https://api.openai.com/profile"]?.email;
			if (typeof email === "string" && email.length > 0) return email;
		} catch (error) {
			throw new Error("Cannot read openai-codex profile from stored access token", { cause: error });
		}
	}
	return undefined;
}

function statusLine(pi: ExtensionAPI, ctx: ExtensionContext, identity: string | undefined, quota: string, branchLabel: string): string {
	const parts: string[] = [];
	const usage = ctx.getContextUsage();
	if (usage) {
		const context =
			usage.tokens === null || usage.percent === null
				? "context unknown"
				: `${formatTokens(usage.tokens)} (${Math.round(usage.percent)}%)`;
		const effortColor = EFFORT_COLORS[pi.getThinkingLevel()];
		parts.push(effortColor ? `${effortColor}${context}${RESET}` : context);
	}

	const cwd = basename(ctx.cwd) || ctx.cwd;
	parts.push(branchLabel || `${GRAY}${cwd}${FG_DEFAULT}`);
	if (quota) parts.push(quota);
	if (identity) parts.push(`${GRAY}${identity.replace(/@[^@]+$/, "")}${FG_DEFAULT}`);

	return ` ${parts.join(" · ")}${RESET}`;
}

export default function ccStatusLine(pi: ExtensionAPI) {
	let context: ExtensionContext | undefined;
	let requestRender: (() => void) | undefined;
	let identity: string | undefined;
	let generationStartedAt: number | undefined;
	let tokensPerSecond: number | undefined;
	let quotaWindows: QuotaWindow[] = [];
	let quotaState = "";
	let quotaAccount: string | undefined;
	let lastQuotaFetch = 0;
	let quotaInterval = QUOTA_POLL_MS;
	let quotaRequest: AbortController | undefined;
	let quotaTimer: ReturnType<typeof setInterval> | undefined;

	const stopQuota = () => {
		if (quotaTimer) clearInterval(quotaTimer);
		quotaTimer = undefined;
		quotaRequest?.abort();
		quotaRequest = undefined;
		quotaWindows = [];
		quotaState = "";
		quotaAccount = undefined;
		lastQuotaFetch = 0;
		quotaInterval = QUOTA_POLL_MS;
	};

	const refreshQuota = async () => {
		const ctx = context;
		if (!ctx) return;
		const provider = ctx.model?.provider;
		const credential = provider === "openai-codex" || provider === "openai" ? readStoredCredential(provider) : undefined;
		const account = credential?.type === "oauth" ? `${provider}:${credential.accountId ?? credential.clientId ?? ""}` : undefined;
		if (account !== quotaAccount) {
			quotaRequest?.abort();
			quotaRequest = undefined;
			quotaWindows = [];
			quotaState = "";
			lastQuotaFetch = 0;
			quotaAccount = account;
		}
		if (account === undefined || credential?.type !== "oauth") return;
		if (quotaRequest || Date.now() - lastQuotaFetch < quotaInterval - QUOTA_TIMER_SLACK_MS) return;
		lastQuotaFetch = Date.now();
		const controller = new AbortController();
		quotaRequest = controller;
		if (!quotaWindows.length) quotaState = "quota …";
		try {
			const viaCodexCli = provider === "openai";
			const auth = viaCodexCli ? codexCliAuth() : { access: credential.access, accountId: credential.accountId };
			if (typeof auth.access !== "string" || !auth.access) throw new Error("Codex quota needs a stored OAuth access token");
			const headers: Record<string, string> = { Authorization: `Bearer ${auth.access}` };
			if (auth.accountId) headers["ChatGPT-Account-Id"] = String(auth.accountId);
			if (viaCodexCli) Object.assign(headers, { "User-Agent": "codex-cli", "OpenAI-Beta": "codex-1", originator: "Codex Desktop" });
			const response = await fetch("https://chatgpt.com/backend-api/wham/usage", {
				headers,
				signal: AbortSignal.any([controller.signal, AbortSignal.timeout(15_000)]),
			});
			let windows: QuotaWindow[];
			if (viaCodexCli && response.status === 401) {
				windows = await quotaViaCodexCliRefreshingItsToken(controller.signal);
			} else {
				if (!response.ok) throw new Error(`Codex quota request failed: HTTP ${response.status}`);
				const body = await response.json();
				windows = parseQuotaWindows(body);
				if (quotaRequest === controller) pi.events.emit("codex-quota-report", { account, body, observedAt: Date.now() });
			}
			if (quotaRequest !== controller) return;
			quotaWindows = windows;
			quotaState = "";
			quotaInterval = QUOTA_POLL_MS;
		} catch (error) {
			if (quotaRequest !== controller || controller.signal.aborted) return;
			quotaWindows = [];
			quotaState = "quota unavailable";
			quotaInterval = QUOTA_POLL_AFTER_FAILURE_MS;
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
		} finally {
			if (quotaRequest === controller) {
				quotaRequest = undefined;
				requestRender?.();
			}
		}
	};

	const clear = () => {
		stopQuota();
		const previous = context;
		context = undefined;
		requestRender = undefined;
		identity = undefined;
		generationStartedAt = undefined;
		tokensPerSecond = undefined;
		previous?.ui.setFooter(undefined);
	};

	const update = (ctx: ExtensionContext) => {
		if (!context) return;
		context = ctx;
		identity = ctx.model ? providerIdentity(ctx.model.provider) : undefined;
		void refreshQuota();
		requestRender?.();
	};

	pi.on("session_start", (_event, ctx) => {
		clear();
		if (ctx.mode !== "tui") return;
		context = ctx;
		identity = ctx.model ? providerIdentity(ctx.model.provider) : undefined;
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
			let statsKey: object | undefined;
			let statsCount = -1;
			let cacheHit: number | undefined;
			let cavemanLevel = "off";
			return {
				render(width: number) {
					if (!context) return [];
					const manager = context.sessionManager;
					const count = manager.getEntryCount();
					if (statsKey !== manager || statsCount !== count) {
						statsKey = manager;
						statsCount = count;
						cacheHit = undefined;
						cavemanLevel = "off";
						for (const entry of manager.getEntries()) {
							if (entry.type === "custom" && entry.customType === "caveman-level") {
								const level = (entry.data as { level?: unknown })?.level;
								if (typeof level === "string") cavemanLevel = level;
							}
							if (entry.type === "message" && entry.message.role === "assistant") {
								const usage = entry.message.usage;
								const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
								cacheHit = prompt > 0 ? usage.cacheRead / prompt * 100 : undefined;
							}
						}
					}
					const statsWidth = Math.max(0, width - 2);
					const branch = footerData.getGitBranch();
					const branchLabel = branch && branch !== "main" ? theme.fg("toolDiffAdded", branch) : "";
					const modelId = context.model?.id;
					const modelLabel = modelId === "gpt-6.1-sol" ? "Sol 6.1" : modelId ?? "no-model";
					const modelColor = /(?:^|[-\s])sol(?:$|[-\s])/i.test(modelLabel) ? "toolDiffAdded"
						: /(?:^|[-\s])astra(?:$|[-\s])/i.test(modelLabel) ? "error" : "dim";
					const cacheText = cacheHit === undefined ? " —" : ` ${cacheHit.toFixed(2)}%`;
					const cacheLabel = cacheHit === undefined || cacheHit > 98 ? ""
						: cacheHit >= 95 ? `\x1b[38;2;255;158;100m${cacheText}${FG_DEFAULT}` : theme.fg("error", cacheText);
					const speedLabel = `${GRAY} ${tokensPerSecond === undefined ? "—" : tokensPerSecond.toFixed(1)} tok/s${FG_DEFAULT}`;
					const cavemanIcons: Record<string, string> = {
						off: "○", lite: "󰧑", full: "󰈸", ultra: "󰓅",
						"wenyan-lite": "󰧑", wenyan: "󰈸", "wenyan-ultra": "󰓅", micro: "󰓅",
					};
					const cavemanIcon = cavemanIcons[cavemanLevel];
					if (!cavemanIcon) throw new Error(`Unknown caveman level: ${cavemanLevel}`);
					const cavemanColor = cavemanLevel === "off" ? "\x1b[2m"
						: cavemanLevel === "lite" || cavemanLevel === "wenyan-lite" ? "\x1b[97m"
						: cavemanLevel === "full" || cavemanLevel === "wenyan" ? "\x1b[91m" : "\x1b[95m";
					const left = truncateToWidth(
						`${cavemanColor}${cavemanIcon}${RESET} ${theme.fg(modelColor, modelLabel)} · ${speedLabel}${cacheLabel ? ` · ${cacheLabel}` : ""}`,
						statsWidth,
						"…",
					);
					const sessionName = manager.getSessionName();
					const rightWidth = Math.max(0, statsWidth - visibleWidth(cavemanIcon) - 4);
					const right = sessionName ? `${GRAY}${truncateToWidth(sessionName, rightWidth, "…")}${FG_DEFAULT}` : "";
					const fittedLeft = right ? truncateToWidth(left, Math.max(0, statsWidth - visibleWidth(right) - 2), "…") : left;
					const padding = Math.max(0, statsWidth - visibleWidth(fittedLeft) - visibleWidth(right));
					const stats = fittedLeft + " ".repeat(padding) + right;
					const statsLine = width < 2 ? " ".repeat(Math.max(0, width))
						: truncateToWidth(` ${stats}${" ".repeat(Math.max(0, statsWidth - visibleWidth(stats)))} `, width, "…");
					const quota = quotaWindows.length ? quotaWindows.map(quotaLabel).join(" · ") : theme.fg("dim", quotaState);
					const firstContent = truncateToWidth(statusLine(pi, context, identity, quota, branchLabel), Math.max(0, width - 1), "…");
					const firstLine = truncateToWidth(`${firstContent}${" ".repeat(Math.max(0, width - visibleWidth(firstContent)))}`, width, "…");
					return [firstLine, statsLine];
				},
				invalidate() {},
				dispose() {
					stopQuota();
					unsubscribe();
					context = undefined;
					requestRender = undefined;
				},
			};
		});
		void refreshQuota();
		quotaTimer = setInterval(() => {
			void refreshQuota();
			requestRender?.();
		}, 60_000);
		quotaTimer.unref();
	});
	pi.on("message_start", (event) => {
		if (event.message.role === "assistant") generationStartedAt = undefined;
	});
	pi.on("message_update", (event) => {
		if (event.message.role !== "assistant" || generationStartedAt !== undefined) return;
		const update = event.assistantMessageEvent;
		if ((update.type === "text_delta" || update.type === "thinking_delta" || update.type === "toolcall_delta") && update.delta.length > 0) {
			generationStartedAt = performance.now();
		}
	});
	pi.on("message_end", (event) => {
		if (event.message.role !== "assistant") return;
		const seconds = generationStartedAt === undefined ? 0 : (performance.now() - generationStartedAt) / 1000;
		const output = event.message.usage.output;
		tokensPerSecond = seconds > 0 && Number.isFinite(output) && output > 0
			&& event.message.stopReason !== "error" && event.message.stopReason !== "aborted"
			? output / seconds : undefined;
		generationStartedAt = undefined;
		requestRender?.();
	});
	pi.on("turn_end", (_event, ctx) => update(ctx));
	pi.on("agent_end", (_event, ctx) => update(ctx));
	pi.on("model_select", (_event, ctx) => update(ctx));
	pi.on("thinking_level_select", (_event, ctx) => update(ctx));
	pi.on("session_compact", (_event, ctx) => update(ctx));
	pi.on("session_tree", (_event, ctx) => update(ctx));
	pi.on("session_shutdown", clear);
}
