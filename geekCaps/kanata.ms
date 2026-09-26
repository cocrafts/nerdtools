import { GeekCaps, Key, Mod } from "./layout";
import { PcChord, PcMod, pcChord } from "./pc";

struct HeldPosition {
	mod: Mod;
	key: string;
}

const heldPositions: HeldPosition[] = [
	{ mod: Mod.Cmd, key: "lalt" },
	{ mod: Mod.Opt, key: "lmet" },
	{ mod: Mod.Ctrl, key: "lctl" },
	{ mod: Mod.Shift, key: "lsft" },
];

const tapRepressMs: int32 = 200;
const holdMs: int32 = 1000;

function kanataKey(key: Key): string {
	return match (key) {
		Key.Num0 => "0",
		Key.Num1 => "1",
		Key.Num2 => "2",
		Key.Num3 => "3",
		Key.Num4 => "4",
		Key.Num5 => "5",
		Key.Num6 => "6",
		Key.Num7 => "7",
		Key.Num8 => "8",
		Key.Num9 => "9",
		Key.A => "a",
		Key.B => "b",
		Key.C => "c",
		Key.D => "d",
		Key.H => "h",
		Key.I => "i",
		Key.J => "j",
		Key.K => "k",
		Key.L => "l",
		Key.M => "m",
		Key.N => "n",
		Key.O => "o",
		Key.P => "p",
		Key.Q => "q",
		Key.S => "s",
		Key.U => "u",
		Key.V => "v",
		Key.X => "x",
		Key.Z => "z",
		Key.F4 => "f4",
		Key.F11 => "f11",
		Key.Backslash => "bksl",
		Key.Backspace => "bspc",
		Key.CapsLock => "caps",
		Key.CloseBracket => "rbrc",
		Key.Comma => "comm",
		Key.DeleteForward => "del",
		Key.DownArrow => "down",
		Key.End => "end",
		Key.EqualSign => "eql",
		Key.Escape => "esc",
		Key.Grave => "grv",
		Key.Home => "home",
		Key.Hyphen => "min",
		Key.LeftArrow => "left",
		Key.OpenBracket => "lbrc",
		Key.Period => "Period",
		Key.Quote => "apos",
		Key.RightArrow => "rght",
		Key.RightCommand => "ralt",
		Key.RightControl => "rctl",
		Key.Semicolon => "scln",
		Key.Slash => "Slash",
		Key.Spacebar => "spc",
		Key.Tab => "tab",
		Key.UpArrow => "up",
	};
}

function pcModKey(mod: PcMod): string {
	return match (mod) {
		PcMod.Ctrl => "lctl",
		PcMod.Alt => "lalt",
		PcMod.Shift => "lsft",
		PcMod.Win => "lmet",
	};
}

function macModName(mod: Mod): string {
	return match (mod) {
		Mod.Cmd => "Cmd",
		Mod.Opt => "Opt",
		Mod.Ctrl => "Ctrl",
		Mod.Shift => "Shift",
		Mod.Fn => "Fn",
	};
}

function macChordName(mods: BitSet<Mod>, key: Key): string {
	let name = "";
	for (const mod of mods) {
		name += macModName(mod) + "+";
	}
	return name + kanataKey(key);
}

function heldCondition(held: BitSet<Mod>): string {
	let pressed = "";
	let released = "";
	for (const position of heldPositions) {
		const check = " (input real " + position.key + ")";
		if (held.has(position.mod)) {
			pressed += check;
		} else {
			released += check;
		}
	}
	if (pressed == "") {
		return "((not" + released + "))";
	}
	if (released == "") {
		return "((and" + pressed + "))";
	}
	return "((and" + pressed + " (not" + released + ")))";
}

function chordAction(chord: PcChord): string {
	let release = "";
	for (const position of heldPositions) {
		release += (release == "" ? "" : " ") + position.key;
	}
	let keys = "";
	for (const mod of chord.mods) {
		keys += pcModKey(mod) + " ";
	}
	return "(unmod (" + release + ") " + keys + kanataKey(chord.key) + ")";
}

function containsKey(keys: Span<Key>, key: Key): boolean {
	for (const candidate of keys) {
		if (candidate == key) {
			return true;
		}
	}
	return false;
}

function containsMods(sets: Span<BitSet<Mod>>, mods: BitSet<Mod>): boolean {
	for (const candidate of sets) {
		if (candidate == mods) {
			return true;
		}
	}
	return false;
}

export function kanataConfig(this geek: GeekCaps): Result<string, string> {
	const fromKeys: Key[] = [];
	for (const group of geek.groups) {
		for (const map of group.maps) {
			if (!containsKey(fromKeys, map.from)) {
				fromKeys.push(map.from);
			}
		}
	}
	let aliases = "";
	let layerRows = "";
	let problems = "";
	for (const from of fromKeys) {
		const seen: BitSet<Mod>[] = [];
		let cases = "";
		for (const group of geek.groups) {
			for (const map of group.maps) {
				if (map.from != from) {
					continue;
				}
				for (const variation of map.variations) {
					const label = "Caps+" + macChordName(variation.held, from);
					if (variation.held.has(Mod.Fn)) {
						problems += label + ": Fn cannot be held on a PC keyboard\n";
						continue;
					}
					if (containsMods(seen, variation.held)) {
						problems += label + ": mapped twice\n";
						continue;
					}
					seen.push(variation.held);
					const chord = pcChord(map.to, variation.send);
					if (!chord.ok) {
						const mac = macChordName(variation.send, map.to);
						problems += label + ": no PC chord for " + mac + "\n";
						continue;
					}
					cases += "\n    " + heldCondition(variation.held) + " " +
						chordAction(chord.value) + " break";
				}
			}
		}
		const alias = "g-" + kanataKey(from);
		aliases += "\n  " + alias + " (switch" + cases + ")";
		layerRows += "\n  " + kanataKey(from) + " @" + alias;
	}
	if (problems != "") {
		return Result.err(problems);
	}
	let heldKeys = "";
	for (const position of heldPositions) {
		heldKeys += (heldKeys == "" ? "" : " ") + position.key;
	}
	let remapRows = "";
	for (const remap of geek.remaps) {
		remapRows += "\n  " + kanataKey(remap.from) + " " + kanataKey(remap.to);
	}
	const layerKey = "geek (tap-hold-press " + String(tapRepressMs) + " " + String(holdMs) + " " +
		kanataKey(geek.layer.tap) + " (layer-while-held geek))";
	return Result.ok(
		"(defcfg\n  process-unmapped-keys yes\n)\n\n" +
		"(defsrc\n  " + heldKeys + "\n)\n\n" +
		"(defalias\n  " + layerKey + aliases + "\n)\n\n" +
		"(deflayermap (base)\n  " + kanataKey(geek.layer.key) + " @geek" + remapRows + "\n)\n\n" +
		"(deflayermap (geek)" + layerRows + "\n  ___ XX\n)\n",
	);
}
