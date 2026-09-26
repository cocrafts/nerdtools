import { ensureDir, writeFile } from "std/fs";
import { homeDir } from "std/os";
import { exit } from "std/process";
import { karabinerJson } from "./karabiner";
import { geekCaps } from "./rules/index";

// PARKED: std/os does not resolve on Raiser, and its header import fails on Windows C. Cards:
// ~/metascript/.inbox/compiler/2026-09-26-raiser-std-os-missing.md
// ~/metascript/.inbox/compiler/2026-09-26-c-header-import-windows-no-sysroot.md
function configHome(): string {
	return homeDir() + "/.config";
}

function main(): int32 {
	const dir = configHome() + "/karabiner/assets/complex_modifications";
	const made = ensureDir(dir);
	if (!made.ok) {
		console.log("cannot create " + dir + ": " + made.error.message);
		return 1;
	}
	const path = dir + "/capslock.json";
	const written = writeFile(path, geekCaps.karabinerJson() + "\n");
	if (!written.ok) {
		console.log("cannot write " + path + ": " + written.error.message);
		return 1;
	}
	console.log("Karabiner configuration written to: " + path);
	return 0;
}

exit(main());
