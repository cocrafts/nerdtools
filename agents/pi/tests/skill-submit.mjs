import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";
import { deflateSync } from "node:zlib";

const root = process.env.PI_PACKAGE_ROOT;
if (!root) throw new Error("Set PI_PACKAGE_ROOT to the installed @earendil-works/pi-coding-agent directory");
const pi = await import(pathToFileURL(join(root, "dist/index.js")).href);
const ai = await import(pathToFileURL(join(root, "node_modules/@earendil-works/pi-ai/dist/index.js")).href);
const { createJiti } = createRequire(join(root, "package.json"))("jiti");
const jiti = createJiti(import.meta.url, { alias: { "@earendil-works/pi-coding-agent": join(root, "dist/index.js"), "@earendil-works/pi-tui": join(root, "node_modules/@earendil-works/pi-tui/dist/index.js") } });
const source = resolve(dirname(fileURLToPath(import.meta.url)), "../extensions/neon-format");
const helper = await jiti.import(join(source, "skill-input.ts"));
const submit = await jiti.import(join(source, "skill-submit.ts"));
const scratch = mkdtempSync(join(tmpdir(), "pi-atom-sdk-"));
let session;
const pngChunk = (type, bytes) => {
	const body = Buffer.concat([Buffer.from(type), bytes]);
	let crc = 0xffffffff;
	for (const byte of body) { crc ^= byte; for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0); }
	const size = Buffer.alloc(4); size.writeUInt32BE(bytes.length);
	const checksum = Buffer.alloc(4); checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
	return Buffer.concat([size, body, checksum]);
};
const header = Buffer.alloc(13); header.writeUInt32BE(1, 0); header.writeUInt32BE(1, 4); header[8] = 8; header[9] = 2;
const image = { type: "image", mimeType: "image/png", data: Buffer.concat([Buffer.from("89504e470d0a1a0a", "hex"), pngChunk("IHDR", header), pngChunk("IDAT", deflateSync(Buffer.from([0, 255, 0, 0]))), pngChunk("IEND", Buffer.alloc(0))]).toString("base64") };
try {
	const agentDir = join(scratch, "agent"); mkdirSync(agentDir);
	const skillsDir = join(scratch, "skills"); mkdirSync(skillsDir);
	for (const name of ["alpha", "beta"]) {
		const dir = join(skillsDir, name); mkdirSync(dir);
		writeFileSync(join(dir, "SKILL.md"), `---\nname: ${name}\ndescription: fixture\n---\nINSTRUCTION_${name.toUpperCase()}\nLiteral /skill:beta in file is opaque.\n`);
	}
	const faux = ai.fauxProvider({ provider: "atom-fixture", models: [{ id: "fixture", input: ["text", "image"] }] });
	const seen = [];
	const response = context => { seen.push(structuredClone(context)); return ai.fauxAssistantMessage("ok"); };
	faux.setResponses(Array.from({ length: 6 }, () => response));
	const settingsManager = pi.SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } });
	let starts = 0;
	const loader = new pi.DefaultResourceLoader({
		cwd: scratch, agentDir, settingsManager, noExtensions: true, noContextFiles: true, noPromptTemplates: true, noThemes: true,
		additionalSkillPaths: [skillsDir], skillsOverride: value => ({ ...value, skills: value.skills.filter(skill => ["alpha", "beta"].includes(skill.name)) }),
		extensionFactories: [api => { api.registerProvider(faux.provider); helper.registerSkillInput(api); api.on("before_agent_start", () => { starts++; }); }],
	});
	await loader.reload();
	({ session } = await pi.createAgentSession({ cwd: scratch, agentDir, settingsManager, resourceLoader: loader, sessionManager: pi.SessionManager.inMemory(scratch), model: faux.getModel(), tools: [] }));
	const errors = [];
	const ui = { getEditorText: () => "", setEditorText() {}, setEditorComponent() {}, notify: (text, kind) => { if (kind === "error") errors.push(text); }, theme: {} };
	await session.bindExtensions({ mode: "tui", uiContext: ui, onError: error => { throw error; } });
	const original = "Review /skill:alpha then /skill:beta";
	await session.prompt(original, { images: [image] });
	assert.equal(starts, 1); assert.equal(seen.length, 1);
	const first = session.messages.find(message => message.role === "user");
	assert.equal((first.content[0].text.match(/<skill name=/g) ?? []).length, 2);
	assert.ok(first.content[0].text.endsWith(original));
	assert.equal(first.content.filter(content => content.type === "image").length, 1);
	const text = JSON.stringify(seen[0].messages);
	assert.ok(text.includes("INSTRUCTION_ALPHA")); assert.ok(text.includes("INSTRUCTION_BETA")); assert.ok(text.includes(original));
	assert.equal(submit.skillPromptInput(first.content[0].text), original);
	const leading = "/skill:alpha /skill:beta do this";
	await session.prompt(leading);
	const second = session.messages.filter(message => message.role === "user").at(-1);
	assert.equal((second.content[0].text.match(/<skill name=/g) ?? []).length, 2);
	assert.ok(second.content[0].text.endsWith(leading));
	await session.prompt("Only /skill:alpha /skill:alpha");
	const single = session.messages.filter(message => message.role === "user").at(-1).content[0].text;
	assert.equal((single.match(/<skill name=/g) ?? []).length, 1);
	assert.ok(!single.includes("INSTRUCTION_BETA"));
	await session.prompt(original, { source: "extension", expandPromptTemplates: false });
	assert.equal(session.messages.filter(message => message.role === "user").at(-1).content[0].text, original);
	let release;
	let ready;
	const started = new Promise(resolve => ready = resolve);
	const blocked = new Promise(resolve => release = resolve);
	faux.setResponses([async context => { seen.push(structuredClone(context)); ready(); await blocked; return ai.fauxAssistantMessage("warmup"); }, response]);
	const run = session.prompt("warmup");
	await started;
	assert.equal(session.isStreaming, true);
	await session.prompt(original, { streamingBehavior: "followUp" });
	release(); await run;
	const queued = session.messages.filter(message => message.role === "user").at(-1).content[0].text;
	assert.ok(queued.includes("INSTRUCTION_ALPHA")); assert.ok(queued.includes("INSTRUCTION_BETA")); assert.ok(queued.endsWith(original));
	assert.ok(JSON.stringify(seen.at(-1).messages).includes("INSTRUCTION_BETA"));
	assert.deepEqual(errors, []);
} finally { await session?.dispose(); rmSync(scratch, { recursive: true, force: true }); }
console.log("PASS: real Pi AgentSession + native faux provider: inline/leading multi-skill, original prompt, native user persistence, before_agent_start, images, deduplication, opaque skill bodies, extension-source isolation, queued follow-up delivery, history projection.");
