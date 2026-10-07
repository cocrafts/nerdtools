import { readFileSync } from "node:fs";
import { dirname } from "node:path";
import { parseSkillBlock, stripFrontmatter } from "@earendil-works/pi-coding-agent";
import { allowsSkillTokens, collapseSkillTokens } from "./skill-atoms.ts";

export interface SkillSource { name: string; path: string }

export function requestedSkills(text: string, known: ReadonlySet<string>): string[] {
	const names: string[] = [];
	collapseSkillTokens(text, known, (_label, expansion) => {
		const name = expansion.slice(7);
		if (!names.includes(name)) names.push(name);
	});
	return names;
}

const attribute = (text: string): string => text.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

export function expandSkills(text: string, sources: ReadonlyMap<string, SkillSource>, names?: readonly string[]): string {
	if (!allowsSkillTokens(text)) return text;
	const requested = names ?? requestedSkills(text, new Set(sources.keys()));
	if (!requested.length) return text;
	const blocks = [...new Set(requested)].map(name => {
		const source = sources.get(name);
		if (!source) throw new Error(`Skill ${JSON.stringify(name)} is no longer registered`);
		let body: string;
		try { body = stripFrontmatter(readFileSync(source.path, "utf8")).trim(); }
		catch (error) { throw new Error(`Cannot load skill ${JSON.stringify(name)} from ${source.path}`, { cause: error }); }
		return `<skill name="${attribute(name)}" location="${attribute(source.path)}">\nReferences are relative to ${dirname(source.path)}.\n\n${body}\n</skill>`;
	});
	return `${blocks.join("\n\n")}\n\n${text}`;
}

export function skillPromptInput(text: string): string {
	const names: string[] = [];
	let prompt = text;
	for (;;) {
		const block = parseSkillBlock(prompt);
		if (!block) break;
		names.push(block.name);
		prompt = block.userMessage ?? "";
	}
	if (!names.length) return text;
	if (requestedSkills(prompt, new Set(names)).length === new Set(names).size) return prompt;
	return `${names.map(name => `/skill:${name}`).join(" ")}${prompt ? ` ${prompt}` : ""}`;
}

export function skillPromptDisplay(markdown: string, known: ReadonlySet<string>): string {
	let text = markdown;
	for (;;) {
		const block = parseSkillBlock(text);
		if (!block) break;
		text = block.userMessage ?? "";
	}
	return collapseSkillTokens(text, known, () => {});
}
