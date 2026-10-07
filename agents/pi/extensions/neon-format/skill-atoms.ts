export const SKILL_CHIP_PATTERN = / [\w-]+(?:\.[\w-]+)*(?:\/[\w-]+(?:\.[\w-]+)*)?(?![\w-])/gu;
const skillTokens = /(^|\s)\/skill:([^\s/]+(?:\/[^\s/]+)?)(?=\s|$)/g;

export function allowsSkillTokens(text: string): boolean {
	const start = text.trimStart();
	if (start.startsWith("/skill:")) return true;
	if (start.startsWith("/") || start.startsWith("!")) return false;
	if (start.charCodeAt(0) !== 36 || start.charCodeAt(1) === 123) return true;
	const length = start.charCodeAt(1) === 36 ? 2 : 1;
	const next = start.charCodeAt(length);
	return !(Number.isNaN(next) || next === 32 || next === 9 || next === 10 || next === 13);
}

export function collapseSkillTokens(text: string, known: ReadonlySet<string>, register: (label: string, expansion: string) => void): string {
	if (!text.includes("/skill:") || !allowsSkillTokens(text)) return text;
	skillTokens.lastIndex = 0;
	return text.replace(skillTokens, (match, delimiter: string, name: string) => {
		if (!known.has(name)) return match;
		const label = ` ${name}`;
		register(label, `/skill:${name}`);
		return `${delimiter}${label}`;
	});
}
