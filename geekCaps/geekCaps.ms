import { ensureDir, writeFile } from "std/fs";
import { homeDir } from "std/os";
import { exit } from "std/process";
import { Keyboard, kanataConfig } from "./kanata";
import { geekCaps } from "./rules/index";

// PARKED: std/os does not resolve on Raiser, and its header import fails on Windows C. Cards:
// ~/metascript/.inbox/compiler/2026-09-26-raiser-std-os-missing.md
// ~/metascript/.inbox/compiler/2026-09-26-c-header-import-windows-no-sysroot.md
function configHome(): string {
	return `${homeDir()}/.config`;
}

function writeConfig(dir: string, file: string, text: string): Result<string, string> {
	const made = ensureDir(dir);
	if (!made.ok) {
		return Result.err(`cannot create ${dir}: ${made.error.message}`);
	}
	const path = `${dir}/${file}`;
	const written = writeFile(path, text);
	if (!written.ok) {
		return Result.err(`cannot write ${path}: ${written.error.message}`);
	}
	return Result.ok(path);
}

when (macos) {
	const keyboard = Keyboard.Mac;
} else {
	const keyboard = Keyboard.Pc;
}

function generate(): Result<string, string> {
	const config = try geekCaps.kanataConfig(keyboard);
	return writeConfig(`${configHome()}/kanata`, "kanata.kbd", config);
}

function main(): int32 {
	const written = generate();
	if (!written.ok) {
		console.log(written.error);
		return 1;
	}
	console.log(`GeekCaps written to ${written.value}`);
	return 0;
}

exit(main());
