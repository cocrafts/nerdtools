import { extname } from "node:path";
import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import hljs from "highlight.js/lib/core";
import { metascriptLanguage } from "./metascript-language.ts";

const highlighter = hljs.newInstance();
highlighter.registerLanguage("metascript", metascriptLanguage);

const scopes: Record<string, ThemeColor> = {
	keyword: "syntaxKeyword",
	built_in: "syntaxType",
	literal: "syntaxNumber",
	number: "syntaxNumber",
	string: "syntaxString",
	char: "syntaxString",
	subst: "text",
	comment: "syntaxComment",
	doctag: "syntaxComment",
	meta: "syntaxKeyword",
	title: "syntaxFunction",
	operator: "syntaxOperator",
};

export function isMetaScriptPath(path: string): boolean {
	return [".ms", ".msc", ".cms"].includes(extname(path).toLowerCase());
}

function decodeText(text: string): string {
	const entities: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', "#x27": "'" };
	return text.replace(/&(amp|lt|gt|quot|#x27);/g, (_, entity: string) => entities[entity]);
}

export function highlightMetaScript(code: string, theme: Theme): string {
	const result = highlighter.highlight(code, { language: "metascript", ignoreIllegals: true });
	if (result.errorRaised) throw new Error(`MetaScript highlighting failed: ${result.errorRaised.message}`);
	const stack: ThemeColor[] = [];
	let output = "";
	for (const part of result.value.split(/(<span class="[^"]+">|<\/span>)/)) {
		if (part === "</span>") {
			if (!stack.pop()) throw new Error("MetaScript highlight output has an unmatched closing span");
		} else if (part.startsWith('<span class="')) {
			const classes = part.slice(13, -2).split(" ");
			const scope = classes.find(value => value.startsWith("hljs-"))?.slice(5);
			let token = scope ? scopes[scope] : undefined;
			if (scope === "title" && (classes.includes("class_") || stack.at(-1) === "syntaxType")) token = "syntaxType";
			if (!token) throw new Error(`Unsupported MetaScript highlight scope: ${classes.join(" ")}`);
			stack.push(token);
		} else {
			const token = stack.at(-1) ?? "text";
			output += decodeText(part).split("\n").map(line => line ? theme.fg(token, line) : line).join("\n");
		}
	}
	if (stack.length) throw new Error("MetaScript highlight output has unclosed spans");
	return output;
}
