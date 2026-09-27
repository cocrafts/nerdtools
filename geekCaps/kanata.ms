import { GeekCaps, Key, Mod, Remap } from "./layout";
import { PcError, PcMod, pcChord } from "./pc";

export enum Host {
	Mac,
	Pc,
}

struct HeldPosition {
	mod: Mod;
	key: string;
}

const heldPositions: HeldPosition[] = [
	{ mod: Mod.Cmd, key: "lmet" },
	{ mod: Mod.Opt, key: "lalt" },
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
		Key.LeftCommand => "lmet",
		Key.LeftControl => "lctl",
		Key.LeftOption => "lalt",
		Key.OpenBracket => "lbrc",
		Key.Period => "Period",
		Key.Quote => "apos",
		Key.RightArrow => "rght",
		Key.RightCommand => "rmet",
		Key.RightControl => "rctl",
		Key.RightOption => "ralt",
		Key.Semicolon => "scln",
		Key.Slash => "Slash",
		Key.Spacebar => "spc",
		Key.Tab => "tab",
		Key.UpArrow => "up",
	};
}

function macModKey(mod: Mod): string {
	return match (mod) {
		Mod.Cmd => "lmet",
		Mod.Opt => "lalt",
		Mod.Ctrl => "lctl",
		Mod.Shift => "lsft",
		Mod.Fn => "fn",
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

function macKeys(key: Key, send: BitSet<Mod>): string {
	let keys = "";
	for (const mod of send) {
		keys += `${macModKey(mod)} `;
	}
	return keys + kanataKey(key);
}

function pcKeys(key: Key, send: BitSet<Mod>): Result<string, PcError> {
	const chord = try pcChord(key, send);
	let keys = "";
	for (const mod of chord.mods) {
		keys += `${pcModKey(mod)} `;
	}
	return Result.ok(keys + kanataKey(chord.key));
}

function sendKeys(this host: Host, key: Key, send: BitSet<Mod>): Result<string, PcError> {
	return match (host) {
		Host.Mac => Result.ok(macKeys(key, send)),
		Host.Pc => pcKeys(key, send),
	};
}

function remaps(this geek: GeekCaps, host: Host): Remap[] {
	return match (host) {
		Host.Mac => geek.macRemaps,
		Host.Pc => geek.pcRemaps,
	};
}

function hasHeldPosition(mod: Mod): boolean {
	for (const position of heldPositions) {
		if (position.mod == mod) {
			return true;
		}
	}
	return false;
}

function heldKeyNames(): string {
	const names: string[] = [];
	for (const position of heldPositions) {
		names.push(position.key);
	}
	return names.join(" ");
}

function heldCondition(held: BitSet<Mod>): string {
	let pressed = "";
	let released = "";
	for (const position of heldPositions) {
		const check = ` (input real ${position.key})`;
		if (held.has(position.mod)) {
			pressed += check;
		} else {
			released += check;
		}
	}
	if (pressed == "") {
		return `((not${released}))`;
	}
	if (released == "") {
		return `((and${pressed}))`;
	}
	return `((and${pressed} (not${released})))`;
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

export function kanataConfig(this geek: GeekCaps, host: Host): Result<string, string> {
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
					const label = `Caps+${macChordName(variation.held, from)}`;
					let unholdable = "";
					for (const mod of variation.held) {
						if (!hasHeldPosition(mod)) {
							unholdable += `${label}: ${macModName(mod)} cannot be held\n`;
						}
					}
					if (unholdable != "") {
						problems += unholdable;
						continue;
					}
					if (containsMods(seen, variation.held)) {
						problems += `${label}: mapped twice\n`;
						continue;
					}
					seen.push(variation.held);
					const keys = host.sendKeys(map.to, variation.send);
					if (!keys.ok) {
						if (keys.error == PcError.Untranslated) {
							const mac = macChordName(variation.send, map.to);
							problems += `${label}: no PC chord for ${mac}\n`;
						}
						continue;
					}
					const condition = heldCondition(variation.held);
					cases += `\n    ${condition} (unmod ${keys.value}) break`;
				}
			}
		}
		const alias = `g-${kanataKey(from)}`;
		aliases += `\n  ${alias} (switch${cases})`;
		layerRows += `\n  ${kanataKey(from)} @${alias}`;
	}
	if (problems != "") {
		return Result.err(problems);
	}
	let remapRows = "";
	for (const remap of geek.remaps(host)) {
		remapRows += `\n  ${kanataKey(remap.from)} ${kanataKey(remap.to)}`;
	}
	const tap = kanataKey(geek.layer.tap);
	return Result.ok(`(defcfg
  process-unmapped-keys yes
)

(defsrc
  ${heldKeyNames()}
)

(defalias
  geek (tap-hold-press ${tapRepressMs} ${holdMs} ${tap} (layer-while-held geek))${aliases}
)

(deflayermap (base)
  ${kanataKey(geek.layer.key)} @geek${remapRows}
)

(deflayermap (geek)${layerRows}
  ___ XX
)
`);
}
