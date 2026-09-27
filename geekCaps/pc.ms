import { Key, Mod, cmd, fn, none, opt, shift } from "./layout";

export enum PcMod {
	Ctrl,
	Alt,
	Shift,
	Win,
}

export const pcNone = 0 as BitSet<PcMod>;
export const pcCtrl = pcNone.incl(PcMod.Ctrl);
export const pcAlt = pcNone.incl(PcMod.Alt);
export const pcShift = pcNone.incl(PcMod.Shift);
const pcWin = pcNone.incl(PcMod.Win);
const pcCtrlShift = pcCtrl | pcShift;

export struct PcChord {
	key: Key;
	mods: BitSet<PcMod>;
}

export enum PcError {
	Untranslated,
	NoEquivalent,
}

struct MacChord {
	key: Key;
	send: BitSet<Mod>;
}

struct Translation {
	key: Key;
	send: BitSet<Mod>;
	chord: PcChord;
}

const translations: Translation[] = [
	{ key: Key.S, send: cmd, chord: { key: Key.S, mods: pcCtrl } },
	{ key: Key.Tab, send: cmd, chord: { key: Key.Tab, mods: pcAlt } },
	{ key: Key.Tab, send: cmd | shift, chord: { key: Key.Tab, mods: pcAlt | pcShift } },
	{ key: Key.LeftArrow, send: cmd, chord: { key: Key.Home, mods: pcNone } },
	{ key: Key.LeftArrow, send: cmd | shift, chord: { key: Key.Home, mods: pcShift } },
	{ key: Key.RightArrow, send: cmd, chord: { key: Key.End, mods: pcNone } },
	{ key: Key.RightArrow, send: cmd | shift, chord: { key: Key.End, mods: pcShift } },
	{ key: Key.Backspace, send: opt, chord: { key: Key.Backspace, mods: pcCtrl } },
	{ key: Key.LeftArrow, send: opt, chord: { key: Key.LeftArrow, mods: pcCtrl } },
	{ key: Key.RightArrow, send: opt, chord: { key: Key.RightArrow, mods: pcCtrl } },
	{ key: Key.UpArrow, send: opt, chord: { key: Key.UpArrow, mods: pcCtrl } },
	{ key: Key.DownArrow, send: opt, chord: { key: Key.DownArrow, mods: pcCtrl } },
	{ key: Key.LeftArrow, send: opt | shift, chord: { key: Key.LeftArrow, mods: pcCtrlShift } },
	{ key: Key.RightArrow, send: opt | shift, chord: { key: Key.RightArrow, mods: pcCtrlShift } },
	{ key: Key.UpArrow, send: opt | shift, chord: { key: Key.UpArrow, mods: pcCtrlShift } },
	{ key: Key.DownArrow, send: opt | shift, chord: { key: Key.DownArrow, mods: pcCtrlShift } },
	{ key: Key.Escape, send: cmd | opt | shift, chord: { key: Key.F4, mods: pcAlt } },
	{ key: Key.F4, send: fn, chord: { key: Key.S, mods: pcWin } },
	{ key: Key.F11, send: none, chord: { key: Key.D, mods: pcWin } },
];

const noEquivalents: MacChord[] = [{ key: Key.Grave, send: cmd }];

function passesThrough(send: BitSet<Mod>): boolean {
	return !send.has(Mod.Cmd) && !send.has(Mod.Opt) && !send.has(Mod.Fn);
}

function sameMods(send: BitSet<Mod>): BitSet<PcMod> {
	let mods = pcNone;
	if (send.has(Mod.Ctrl)) {
		mods = mods.incl(PcMod.Ctrl);
	}
	if (send.has(Mod.Shift)) {
		mods = mods.incl(PcMod.Shift);
	}
	return mods;
}

export function pcChord(key: Key, send: BitSet<Mod>): Result<PcChord, PcError> {
	for (const translation of translations) {
		if (translation.key == key && translation.send == send) {
			return Result.ok(translation.chord);
		}
	}
	for (const chord of noEquivalents) {
		if (chord.key == key && chord.send == send) {
			return Result.err(PcError.NoEquivalent);
		}
	}
	if (passesThrough(send)) {
		return Result.ok({ key, mods: sameMods(send) });
	}
	return Result.err(PcError.Untranslated);
}
