import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { AtomicSkillEditor, type SkillDraft } from "./atomic-skill-editor.ts";
import { SKILL_CHIP_PATTERN, allowsSkillTokens } from "./skill-atoms.ts";
import { expandSkills, skillPromptDisplay, type SkillSource } from "./skill-submit.ts";

export { AtomicSkillEditor as SkillInputEditor } from "./atomic-skill-editor.ts";

export function expandSkillChip(text: string, known: ReadonlySet<string>): string {
	if (!allowsSkillTokens(text)) return text;
	return text.replace(SKILL_CHIP_PATTERN, label => known.has(label.slice(2)) ? `/skill:${label.slice(2)}` : label);
}

interface DraftRequest { sessionId: string; restore: (draft: SkillDraft) => void }
const draftChannel = "neon-format:skill-input-draft";

export function registerSkillInput(pi: ExtensionAPI): void {
	let known = new Set<string>();
	let sources = new Map<string, SkillSource>();
	let editor: AtomicSkillEditor | undefined;
	const prepared = new Map<string, string[]>();
	pi.registerMarkdownTransformer((markdown, context) => context.messageType === "user" ? skillPromptDisplay(markdown, known) : markdown);
	pi.on("session_start", (_event, ctx) => {
		sources = new Map(pi.getCommands().filter(command => command.source === "skill").map(command => {
			const name = command.name.replace(/^skill:/, "");
			const path = command.sourceInfo?.path;
			if (!path) throw new Error(`Registered skill ${JSON.stringify(name)} has no source path`);
			return [name, { name, path }];
		}));
		known = new Set(sources.keys());
		if (ctx.mode !== "tui") return;
		const draft = ctx.ui.getEditorText();
		ctx.ui.setEditorComponent((tui, theme, keys) => {
			editor = new AtomicSkillEditor(tui, theme, keys, () => known, () => ctx.ui.theme, text => {
				try {
					const canonical = text.trim();
					const expanded = expandSkills(canonical, sources);
					if (expanded !== canonical) {
						const queue = prepared.get(canonical) ?? [];
						queue.push(expanded); prepared.set(canonical, queue);
						if (prepared.size > 32) prepared.delete(prepared.keys().next().value!);
					}
					return true;
				} catch (error) { ctx.ui.notify(error instanceof Error ? error.message : String(error), "error"); return false; }
			}, error => ctx.ui.notify(error.message, "error"));
			return editor;
		});
		ctx.ui.setEditorText(draft);
		pi.events.emit(draftChannel, { sessionId: ctx.sessionManager.getSessionId(), restore: (snapshot: SkillDraft) => editor?.restoreDraft(snapshot) } satisfies DraftRequest);
	});
	pi.on("input", (event, ctx) => {
		if (ctx.mode !== "tui" || event.source !== "interactive") return;
		try {
			const queue = prepared.get(event.text);
			const text = queue?.shift() ?? expandSkills(event.text, sources);
			if (queue && !queue.length) prepared.delete(event.text);
			if (text !== event.text) return { action: "transform", text };
		} catch (error) {
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			ctx.ui.setEditorText(event.text);
			return { action: "handled" };
		}
	});
	pi.on("session_shutdown", (event, ctx) => {
		editor?.dispose();
		if (event.reason !== "reload" || ctx.mode !== "tui") return;
		const snapshot = editor?.getDraft();
		const sessionId = ctx.sessionManager.getSessionId();
		if (snapshot) {
			const off = pi.events.on(draftChannel, (payload: unknown) => {
				const request = payload as DraftRequest;
				if (!request || typeof request.sessionId !== "string" || typeof request.restore !== "function") throw new Error("Invalid skill editor draft restore request");
				if (request.sessionId !== sessionId) return;
				request.restore(snapshot); off();
			});
		}
		const draft = ctx.ui.getEditorText();
		ctx.ui.setEditorComponent(undefined);
		ctx.ui.setEditorText(draft);
	});
}
