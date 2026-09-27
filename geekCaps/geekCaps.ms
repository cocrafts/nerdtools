import { ensureDir, writeFile } from "std/fs";
import { homeDir } from "std/os";
import { exit } from "std/process";
import { Host, kanataConfig } from "./kanata";
import { geekCaps } from "./rules/index";

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
	const host = Host.Mac;
} else {
	const host = Host.Pc;
}

function generate(): Result<string, string> {
	const config = try geekCaps.kanataConfig(host);
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
