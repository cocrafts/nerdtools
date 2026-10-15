import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text, stripTerminalSequences } from "@earendil-works/pi-tui";

const messageType = "idle-recap";
const idleMs = 3 * 60 * 1000;
const maxReadyRescuesPerRun = 1;
type StopStatus = "ready" | "blocked" | "done" | "unknown";
const instruction = `Before ending a response, check the current user-approved scope:
- ready: authorized work remains and can proceed. Continue using tools; do not stop after one small slice or ask for the same approval again.
- blocked: remaining work requires an actual dependency, permission or decision. State what is missing, who/action unlocks it, and why no independent approved work can continue.
- done: the approved scope is finished with the required verification. Summarize result and next action, if any.
Never infer approval, reopen paused work, broaden scope, bypass safeguards or claim unverified completion. Discussion/questions do not authorize implementation.
For ordinary final answers append a separate final block outside code fences:
<pi_idle_recap status="ready|blocked|done">
A concise truthful state and next action in the user's language. At most 3 lines and 600 characters. Use one actual status value, not the literal alternatives.
</pi_idle_recap>
If you nevertheless stop with authorized ready work, declare ready; a bounded stop check may continue that same work. This metadata grants no authority. Omit metadata when the user requires an exact output format.`;

export function recapFooter(text: string): { body: string; recap?: string; status?: StopStatus } {
	const match = /\n<pi_idle_recap(?: status="(ready|blocked|done)")?>\s*\n([\s\S]*?)\n<\/pi_idle_recap>\s*$/.exec(text);
	if (!match) return { body: text };
	const recap = match[2].trim();
	if (!recap || recap.length > 600 || recap.split("\n").length > 3) return { body: text };
	return { body: text.slice(0, match.index).trimEnd(), recap, status: (match[1] as StopStatus | undefined) ?? "unknown" };
}

export default function idleRecap(pi: ExtensionAPI): void {
	let timer: ReturnType<typeof setTimeout> | undefined;
	let pending: { recap: string; status: StopStatus } | undefined;
	let readyRescues = 0;
	const cancel = (): void => {
		if (timer) clearTimeout(timer);
		timer = undefined;
		pending = undefined;
	};
	pi.on("before_agent_start", (event, ctx) => {
		readyRescues = 0;
		if (ctx.mode === "tui") return { systemPrompt: `${event.systemPrompt}\n\n${instruction}` };
	});
	pi.registerMarkdownTransformer((markdown, context) => context.messageType === "assistant" ? recapFooter(markdown).body : markdown);
	pi.registerMessageRenderer(messageType, (message, options, theme) => {
		const text = typeof message.content === "string" ? message.content : "";
		const status = (message.details as { status?: StopStatus } | undefined)?.status;
		const label = status === "blocked" ? "blocked" : status === "ready" ? "ready" : status === "done" ? "recap" : "status";
		return new Text(theme.fg("dim", `󰋚 ${label}: ${stripTerminalSequences(text)}`), options.outputPad, 0);
	});
	pi.on("context", event => {
		const lastReply = event.messages.findLastIndex(message => message.role === "assistant" || message.role === "user");
		return { messages: event.messages.filter((message, index) => !(message.role === "custom" &&
			(message.customType === messageType || (message.customType === "stop-check" && index < lastReply)))) };
	});
	pi.on("agent_start", cancel);
	pi.on("input", cancel);
	pi.on("session_start", cancel);
	pi.on("session_before_switch", cancel);
	pi.on("session_before_tree", cancel);
	pi.on("session_before_fork", cancel);
	pi.on("session_shutdown", cancel);
	pi.on("message_end", (event, ctx) => {
		if (ctx.mode !== "tui" || event.message.role !== "assistant") return;
		pending = undefined;
		if (event.message.stopReason !== "stop") return;
		const text = event.message.content.filter(block => block.type === "text").map(block => block.text).join("\n");
		const parsed = recapFooter(text);
		pending = parsed.recap ? { recap: parsed.recap, status: parsed.status ?? "unknown" }
			: { recap: "Agent đã dừng; chưa xác định xong hay blocked.", status: "unknown" };
	});
	pi.on("agent_before_settle", (event, ctx) => {
		if (ctx.mode !== "tui" || event.outcome !== "completed" || pending?.status !== "ready") return;
		if (readyRescues >= maxReadyRescuesPerRun) {
			pending = { status: "ready", recap: `Agent vẫn dừng khi còn việc đã duyệt: ${pending.recap}` };
			return;
		}
		readyRescues++;
		return {
			continue: true,
			entries: [{ type: "custom_message", customType: "stop-check", display: false,
				content: `You reported authorized ready work. Continue only that already-approved work now. If actually blocked, explain the blocker and unlock action; if finished, report verified completion. Do not invent permission or expand scope.` }],
		};
	});
	pi.on("agent_settled", (event, ctx) => {
		if (event.aborted || !pending || ctx.mode !== "tui") { cancel(); return; }
		if (timer) clearTimeout(timer);
		const recap = pending;
		const sessionId = ctx.sessionManager.getSessionId();
		timer = setTimeout(() => {
			timer = undefined;
			pending = undefined;
			if (!ctx.isIdle() || ctx.sessionManager.getSessionId() !== sessionId) return;
			pi.sendMessage({ customType: messageType, content: recap.recap, details: { status: recap.status }, display: true }, { triggerTurn: false });
		}, idleMs);
		timer.unref?.();
	});
}
