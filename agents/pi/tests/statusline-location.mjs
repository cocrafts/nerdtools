import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const require = createRequire(join(root, "package.json"));
const { createJiti } = require("jiti");
const loader = createJiti(import.meta.url, { alias: {
	"@earendil-works/pi-coding-agent": join(root, "dist/index.js"),
	"@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"),
} });
const { default: extension } = await loader.import(fileURLToPath(new URL("../extensions/cc-statusline.ts", import.meta.url)));
const { createEventBus } = await loader.import(join(root, "dist/index.js"));
const { visibleWidth } = await loader.import(join(root, "node_modules/@earendil-works/pi-tui/dist/index.js"));
const handlers = {};
let footer;
let gitBranch;
const ctx = {
	cwd: "/Users/le/nerdtools",
	mode: "tui",
	getContextUsage: () => undefined,
	sessionManager: {
		getEntryCount: () => 0, getEntries: () => [], getBranch: () => [],
		getLeafId: () => null, getSessionName: () => undefined, getSessionId: () => "location-test",
	},
	ui: { setFooter: factory => {
		if (factory) footer = factory({ requestRender() {} }, {
			fg: (color, text) => color === "toolDiffAdded" ? `\x1b[32m${text}\x1b[39m` : text,
		}, { onBranchChange: () => () => {}, getGitBranch: () => gitBranch });
	} },
};
const lines = () => footer.render(120).map(line => line.replace(/\x1b\[[0-9;]*m/g, ""));
try {
	extension({ events: createEventBus(), on: (name, handler) => handlers[name] = handler, getThinkingLevel: () => "medium" });
	handlers.session_start({}, ctx);
	for (const branch of [undefined, "main", "wt/skill-input", "feature/長い名前".repeat(20), "main", undefined]) {
		gitBranch = branch;
		if (!branch || branch === "main") assert.equal(lines()[0].trim(), "nerdtools");
		else {
			assert.ok(!lines()[0].includes("nerdtools"));
			assert.ok(!lines()[1].includes(branch));
			if (branch === "wt/skill-input") {
				assert.equal(lines()[0].trim(), branch);
				assert.ok(footer.render(120)[0].includes(`\x1b[32m${branch}\x1b[39m`));
			}
		}
		for (const width of [0, 1, 2, 8, 20, 60, 120]) {
			for (const line of footer.render(width)) assert.ok(visibleWidth(line) <= width);
		}
	}
	console.log("PASS statusline location: folder/main, green feature branch, row-two deduplication, branch changes, narrow Unicode widths");
} finally {
	handlers.session_shutdown?.();
}
