import { execFileCapture, env, argv } from "std/process";
import { writeStdout } from "std/io";
import { readFile } from "std/fs";
import { terminalHost } from "../../../../metascript/neon/src/platform/terminal/host";
import { paintNode, cells } from "../../../../metascript/neon/src/platform/terminal/paint";
import { TerminalNode } from "../../../../metascript/neon/src/platform/terminal/types";

@include("./self.h");
@compile("./self.c");
extern function clqSelf(out buf: Span<float64>): int32;

const PROFILES = 6;
const WARN_PCT = 70;
const CRIT_PCT = 90;
const GAP = 2;
const WEEK_MS = 7 * 86400 * 1000;
// An hour in, summed over the accounts, before the pace says anything.
const MIN_ELAPSED = 1 / 168;
// The widest a quota column can get ("100%-6d23h"), so columns do not shift between refreshes.
const QUOTA_COL = 10;

interface Window {
	utilization: number;
	resets_at: string | null;
}

interface Usage {
	five_hour: Window | null;
	seven_day: Window | null;
}

interface OauthCreds {
	accessToken: string;
	expiresAt: number;
}

// A Console (API-billed) login keeps no claude.ai OAuth token: the item holds no claudeAiOauth.
interface Keychain {
	claudeAiOauth: OauthCreds | null;
}

interface Account {
	emailAddress: string;
}

interface ClaudeJson {
	oauthAccount: Account | null;
}

interface Segment {
	text: string;
	color: string;
	dim: boolean;
}

// A row's quota is two columns (hourly, weekly) or one error spanning both.
interface Row {
	quota: string[];
	name: string;
	browser: string;
	week: Window | null;
}

interface Frame {
	lines: string[];
	width: int32;
	average: string;
}

const host = terminalHost();

// A label is "<name>\t<browser>"; the browser is drawn right-aligned at the terminal's edge.
const LABELS = new Map<string, string>([
	["l3haoson@gmail.com", "l3haoson\tfirefox"],
	["admin@metacraft.studio", "admin\taside"],
	["zang@metacraft.studio", "zang\tsafari"],
	["kayaba.fluctlight@gmail.com", "kayaba\tchrome"],
	["community@mindd.ai", "community\tcomet"],
]);

function paintSegment(seg: Segment): string {
	const node = host.createElement("span");
	if (seg.color !== "") { host.setAttr(node, "color", seg.color); }
	if (seg.dim) { host.setAttr(node, "dim", "true"); }
	const tn = node as unknown as TerminalNode;
	tn.text = seg.text;
	return paintNode(tn, seg.text.length as int32)[0];
}

function paintAll(segs: Segment[]): string {
	let out = "";
	for (const s of segs) {
		if (s.text !== "") { out += paintSegment(s); }
	}
	return out;
}

// The usage API answers resets_at in UTC ("2026-11-03T18:30:00.129826+00:00").
function utcMs(iso: string): number {
	if (!iso.endsWith("+00:00") && !iso.endsWith("Z")) { throw new Error(`resets_at is not UTC: ${iso}`); }
	let y = Number(iso.slice(0, 4));
	const mo = Number(iso.slice(5, 7));
	const d = Number(iso.slice(8, 10));
	y -= mo <= 2 ? 1 : 0;
	const era = Math.floor(y / 400);
	const yoe = y - era * 400;
	const doy = Math.floor((153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5) + d - 1;
	const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
	const days = era * 146097 + doe - 719468;
	const secs = Number(iso.slice(11, 13)) * 3600 + Number(iso.slice(14, 16)) * 60 + Number(iso.slice(17, 19));
	return (days * 86400 + secs) * 1000;
}

function countdown(resetsAt: string | null, nowMs: number): string {
	if (resetsAt === null) { return ""; }
	const s = Math.floor((utcMs(resetsAt as string) - nowMs) / 1000);
	if (s <= 0) { return ""; }
	const d = Math.floor(s / 86400);
	const h = Math.floor((s % 86400) / 3600);
	const m = Math.floor((s % 3600) / 60);
	if (d > 0) { return `-${d}d${h}h`; }
	if (h > 0) { return `-${h}h${m}m`; }
	if (m > 0) { return `-${m}m`; }
	return "-<1m";
}

function windowSegments(w: Window | null, nowMs: number): Segment[] {
	if (w === null) { return [{ text: "--", color: "", dim: true }]; }
	const win = w as Window;
	const pct = Math.round(win.utilization);
	const color = pct >= CRIT_PCT ? "red" : pct >= WARN_PCT ? "yellow" : "";
	return [
		{ text: `${pct}%`, color, dim: false },
		{ text: countdown(win.resets_at, nowMs), color: "", dim: true },
	];
}

function sha8(s: string): string {
	const r = execFileCapture("/bin/sh", ["-c", `printf %s "$1" | /usr/bin/shasum -a 256`, "sh", s]);
	if (!r.ok) { throw new Error(`shasum failed: ${r.error.message}`); }
	return r.value.slice(0, 8);
}

function labelOf(dir: string): string {
	const raw = readFile(`${dir}/.claude.json`);
	if (!raw.ok) { return dir; }
	const parsed = JSON.parse<ClaudeJson>(raw.value);
	if (!parsed.ok || parsed.value.oauthAccount === null) { return dir; }
	const email = (parsed.value.oauthAccount as Account).emailAddress;
	const label = LABELS.get(email);
	return label !== null && label !== undefined ? label : email.split("@")[0];
}

const EXPIRED = "expired";
// API-billed: no 5-hour or weekly quota exists to show.
const CONSOLE = "console";

// Tokens the usage API refused (401): never sent again. A profile opened in Claude Code gets a new token,
// which is polled again.
const refused = new Set<string>();

function usageOf(dir: string): Result<Usage, string> {
	const secret = execFileCapture("/usr/bin/security", ["find-generic-password", "-s", `Claude Code-credentials-${sha8(dir)}`, "-w"]);
	if (!secret.ok) { return Result.err("not logged in"); }
	const creds = JSON.parse<Keychain>(secret.value.trim());
	if (!creds.ok) { return Result.err(`keychain: ${creds.error}`); }
	if (creds.value.claudeAiOauth === null) { return Result.err(CONSOLE); }
	const oauth = creds.value.claudeAiOauth as OauthCreds;
	const token = oauth.accessToken;
	if (oauth.expiresAt <= Date.now() || refused.has(token)) { return Result.err(EXPIRED); }
	const body = execFileCapture("/usr/bin/curl", [
		"-s", "--max-time", "10", "-w", "\n%{http_code}", "https://api.anthropic.com/api/oauth/usage",
		"-H", `Authorization: Bearer ${token}`,
		"-H", "anthropic-beta: oauth-2025-04-20",
	]);
	if (!body.ok) { return Result.err("usage request failed (network?)"); }
	const cut = body.value.lastIndexOf("\n");
	const status = body.value.slice(cut + 1);
	if (status === "429") { return Result.err("rate limited (HTTP 429)"); }
	if (status === "401") {
		refused.add(token);
		return Result.err(EXPIRED);
	}
	if (status !== "200") { return Result.err(`usage: HTTP ${status}`); }
	const usage = JSON.parse<Usage>(body.value.slice(0, cut));
	if (!usage.ok) { return Result.err(`usage: ${usage.error}`); }
	return Result.ok(usage.value);
}

function row(dir: string, nowMs: number): Row {
	const label = labelOf(dir).split("\t");
	const usage = usageOf(dir);
	const quota = usage.ok
		? [paintAll(windowSegments(usage.value.five_hour, nowMs)), paintAll(windowSegments(usage.value.seven_day, nowMs))]
		: [paintSegment({ text: usage.error, color: usage.error === EXPIRED || usage.error === CONSOLE ? "gray" : "red", dim: false })];
	return { quota, name: label[0], browser: label.length > 1 ? label[1] : "", week: usage.ok ? usage.value.seven_day : null };
}

function pad(s: string, width: int32): string {
	return s + " ".repeat(Math.max(0, width - cells(s)));
}

// The terminal's columns, or 0 when there is no terminal (a pipe): the block's own width is used then.
function terminalColumns(): int32 {
	const r = execFileCapture("/bin/sh", ["-c", "stty size < /dev/tty 2>/dev/null"]);
	if (!r.ok) { return 0; }
	const f = r.value.trim().split(" ");
	return f.length === 2 ? Number(f[1]) as int32 : 0;
}

function pctSegment(pct: number): Segment {
	const p = Math.round(pct);
	return { text: `${p}%`, color: p >= CRIT_PCT ? "red" : p >= WARN_PCT ? "yellow" : "", dim: false };
}

// Pooled weekly pace: the share of quota used over the share of the week elapsed, summed across the accounts
// that answered (an expired or failing one is left out). 100% means every account ends its week exactly at its limit.
// Summing before dividing keeps an account that just reset, with a tiny elapsed share, from blowing the ratio up.
function paceOf(rows: Row[], nowMs: number): string {
	let used: number = 0;
	let elapsed: number = 0;
	for (const r of rows) {
		if (r.week === null || (r.week as Window).resets_at === null) { continue; }
		const w = r.week as Window;
		const left = (utcMs(w.resets_at as string) - nowMs) / WEEK_MS;
		used += w.utilization / 100;
		elapsed += Math.min(1, Math.max(0, 1 - left));
	}
	if (elapsed < MIN_ELAPSED) { return ""; }
	const pace = Math.round(100 * used / elapsed);
	return paintAll([{ text: "pace ", color: "", dim: true }, { text: `${pace}%`, color: pace >= 100 ? "red" : "", dim: false }]);
}

function frame(home: string): Frame {
	const nowMs = Date.now();
	const rows: Row[] = [];
	for (let i = 1; i <= PROFILES; i += 1) { rows.push(row(`${home}/.claude-${i}`, nowMs)); }
	let hourly: int32 = QUOTA_COL;
	let weekly: int32 = QUOTA_COL;
	for (const r of rows) {
		if (r.quota.length === 2) {
			hourly = Math.max(hourly, cells(r.quota[0]));
			weekly = Math.max(weekly, cells(r.quota[1]));
		}
	}
	const quotaWidth = hourly + GAP + weekly;
	const lefts: string[] = [];
	let width = 0;
	for (let i = 0; i < rows.length; i += 1) {
		const r = rows[i];
		const q = r.quota.length === 2 ? pad(r.quota[0], hourly + GAP) + pad(r.quota[1], weekly) : pad(r.quota[0], quotaWidth);
		const left = `cl${i + 1}` + " ".repeat(GAP) + q + " ".repeat(GAP) + r.name;
		lefts.push(left);
		width = Math.max(width, cells(left) + GAP + cells(r.browser));
	}
	width = Math.max(width, terminalColumns());
	const lines: string[] = [];
	for (let i = 0; i < rows.length; i += 1) {
		const b = rows[i].browser;
		lines.push(b === "" ? lefts[i] : lefts[i] + " ".repeat(width - cells(lefts[i]) - cells(b)) + b);
	}
	return { lines, width, average: paceOf(rows, nowMs) };
}

function withRight(left: string, right: string, width: int32): string {
	return left + " ".repeat(Math.max(GAP, width - cells(left) - cells(right))) + right;
}

function sampleSelf(): float64[] {
	const row = new Array<float64>(2);
	if (clqSelf(row) !== 0) { throw new Error("clqSelf: proc_pidinfo on this process failed"); }
	return row;
}

function intervalMs(arg: string): number {
	const unit = arg.endsWith("m") ? 60000 : 1000;
	const n = Number(arg.endsWith("m") || arg.endsWith("s") ? arg.slice(0, arg.length - 1) : arg);
	if (!(n >= 1)) { throw new Error(`usage: clq [--once | <seconds> | <n>s | <n>m], got "${arg}"`); }
	return n * unit;
}

function untilNext(ms: number): string {
	const s = Math.max(0, Math.ceil(ms / 1000));
	const sec = s % 60;
	return `${Math.floor(s / 60)}:${sec < 10 ? "0" : ""}${sec}`;
}

// Kept in a function: on C, closures over a top-level block's let do not share it (compiler inbox card
// 2026-10-19-a-closure-env-is-null-when-a-block-local-is-first-captured-in-an-arm-not-taken.md).
function watch(home: string, every: number): void {
	let drawn = 0;
	let nextAt: number = 0;
	let lastCpuNs: float64 = sampleSelf()[0];
	let lastAt: number = Date.now();
	let width: int32 = 0;
	let average = "";
	const footer = (): string => {
		const now = Date.now();
		const self = sampleSelf();
		const cpu = now > lastAt ? 100 * (self[0] - lastCpuNs) / ((now - lastAt) * 1000000) : 0;
		lastCpuNs = self[0];
		lastAt = now;
		const text = `${untilNext(nextAt - now)} · cpu ${cpu.toFixed(1)}% · ram ${(self[1] / 1048576).toFixed(1)}MB`;
		return withRight(paintSegment({ text, color: "", dim: true }), average, width);
	};
	const refresh = (): void => {
		const f = frame(home);
		const lines = f.lines;
		width = f.width;
		average = f.average;
		nextAt = Date.now() + every;
		lines.push(footer());
		let out = drawn > 0 ? `\x1b[${drawn}A` : "";
		for (const l of lines) { out += `\x1b[2K${l}\n`; }
		writeStdout(out);
		drawn = lines.length;
	};
	refresh();
	setInterval((): void => {
		if (Date.now() >= nextAt) { refresh(); } else { writeStdout(`\x1b[1A\x1b[2K${footer()}\n`); }
	}, 1000);
}

const home = env.get("HOME");
const arg = argv.length > 1 ? argv[1] : "5m";
if (arg === "--once") {
	const f = frame(home);
	for (const l of f.lines) { console.log(l); }
	if (f.average !== "") { console.log(withRight("", f.average, f.width)); }
} else {
	watch(home, intervalMs(arg));
}
