import { basename } from "node:path";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import type { Component, TuiMouseEvent, TuiMouseEventResult } from "@earendil-works/pi-tui";
import { Markdown, truncateToWidth } from "@earendil-works/pi-tui";

interface Expansion {
	expanded: boolean;
	nativeExpanded: boolean;
}

export function contextFileNames(content: string): string[] {
	const paths = [
		...content.matchAll(/^Card of this worktree, (.+):$/gm),
		...content.matchAll(/^Handoff from the previous session, (.+?), written /gm),
		...content.matchAll(/^(?:HANDOFF|BOARD) (.+?) —/gm),
	].map(match => match[1]);
	return [...new Set(paths)].map(path => path.includes("/handoff/") ? `handoff/${basename(path)}` : basename(path));
}

class ContextMessage implements Component {
	private body: Markdown;

	constructor(private content: string, private state: Expansion, private theme: Theme, private outputPad: number) {
		this.body = new Markdown(content, outputPad, 0, getMarkdownTheme());
	}

	render(width: number): string[] {
		const label = contextFileNames(this.content).join(" · ") || "Worktree context";
		const arrow = this.state.expanded ? "▾" : "▸";
		const header = truncateToWidth(" ".repeat(this.outputPad) + this.theme.fg("customMessageLabel", `${arrow} ${label}`), width, "…");
		return this.state.expanded ? [header, ...this.body.render(width)] : [header];
	}

	handleMouse(event: TuiMouseEvent): TuiMouseEventResult | undefined {
		if (event.type !== "click" || event.button !== "left" || event.y !== 0) return undefined;
		this.state.expanded = !this.state.expanded;
		return { handled: true, render: true };
	}

	invalidate(): void { this.body.invalidate(); }
}

export function registerContextMessage(pi: ExtensionAPI): void {
	const states = new WeakMap<object, Expansion>();
	pi.registerMessageRenderer("claude-context", (message, options, theme) => {
		let state = states.get(message);
		if (!state) {
			state = { expanded: options.expanded, nativeExpanded: options.expanded };
			states.set(message, state);
		} else if (state.nativeExpanded !== options.expanded) {
			state.expanded = options.expanded;
			state.nativeExpanded = options.expanded;
		}
		const content = typeof message.content === "string" ? message.content
			: message.content.filter(block => block.type === "text").map(block => block.text).join("\n");
		return new ContextMessage(content, state, theme, options.outputPad);
	});
}
