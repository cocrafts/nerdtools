import type { Theme } from "@earendil-works/pi-coding-agent";
import { getLanguageFromPath, highlightCode } from "@earendil-works/pi-coding-agent";
import { highlightMetaScript, isMetaScriptPath } from "./metascript-highlight.ts";

export function highlightFile(code: string, path: string, theme: Theme): string {
	if (isMetaScriptPath(path)) return highlightMetaScript(code, theme);
	const language = getLanguageFromPath(path);
	return language ? highlightCode(code, language).join("\n") : theme.fg("toolOutput", code);
}
