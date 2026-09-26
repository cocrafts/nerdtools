import { JsonValue } from "std/serialize/json/types";
import { jsonArray, jsonObject, jsonString } from "std/serialize/json/builder";
import { stringifyPretty } from "std/serialize/json/stringify";
import { GeekCaps, Key, KeyMap, Layer, Mod, Remap, RuleGroup, Variation } from "./layout";

const exportUrl = "https://raw.githubusercontent.com/cloudle/geekCaps/master/exports/" +
	"karabiner.json";
const importPrefix = "karabiner://karabiner/assets/complex_modifications/import?url=";
const layerTitle = "CapsLock to GeekCaps";
const layerModifiers: string[] = ["right_command", "right_control", "right_option"];
const layerHeld: string[] = ["right_command", "right_control", "right_option", "right_shift"];

function keyCode(key: Key): string {
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
		Key.Backslash => "backslash",
		Key.Backspace => "delete_or_backspace",
		Key.CapsLock => "caps_lock",
		Key.CloseBracket => "close_bracket",
		Key.Comma => "comma",
		Key.DeleteForward => "delete_forward",
		Key.DownArrow => "down_arrow",
		Key.EqualSign => "equal_sign",
		Key.Escape => "escape",
		Key.Grave => "grave_accent_and_tilde",
		Key.Hyphen => "hyphen",
		Key.LeftArrow => "left_arrow",
		Key.OpenBracket => "open_bracket",
		Key.Period => "period",
		Key.Quote => "quote",
		Key.RightArrow => "right_arrow",
		Key.RightCommand => "right_command",
		Key.RightControl => "right_control",
		Key.Semicolon => "semicolon",
		Key.Slash => "slash",
		Key.Spacebar => "spacebar",
		Key.Tab => "tab",
		Key.UpArrow => "up_arrow",
	};
}

function modifierName(mod: Mod): string {
	return match (mod) {
		Mod.Cmd => "left_command",
		Mod.Opt => "left_option",
		Mod.Ctrl => "left_control",
		Mod.Shift => "left_shift",
		Mod.Fn => "fn",
	};
}

function strings(values: Span<string>): JsonValue {
	const items: JsonValue[] = [];
	for (const value of values) {
		items.push(jsonString(value));
	}
	return jsonArray(items);
}

function modifierNames(mods: BitSet<Mod>): string[] {
	const names: string[] = [];
	for (const mod of mods) {
		names.push(modifierName(mod));
	}
	return names;
}

function keyCodeOnly(key: Key): JsonValue {
	return jsonObject(["key_code"], [jsonString(keyCode(key))]);
}

function fromAnyModifiers(key: Key): JsonValue {
	return jsonObject(
		["key_code", "modifiers"],
		[jsonString(keyCode(key)), jsonObject(["optional"], [strings(["any"])])],
	);
}

function layerManipulator(this layer: Layer): JsonValue {
	const shiftWithLayer = jsonObject(
		["key_code", "modifiers"],
		[jsonString("right_shift"), strings(layerModifiers)],
	);
	return jsonObject(
		["from", "to", "to_if_alone", "type"],
		[
			fromAnyModifiers(layer.key),
			jsonArray([shiftWithLayer]),
			jsonArray([keyCodeOnly(layer.tap)]),
			jsonString("basic"),
		],
	);
}

function remapManipulator(this remap: Remap): JsonValue {
	return jsonObject(
		["from", "to", "type"],
		[fromAnyModifiers(remap.from), jsonArray([keyCodeOnly(remap.to)]), jsonString("basic")],
	);
}

function variationManipulator(this map: KeyMap, variation: Variation): JsonValue {
	const mandatory: string[] = [];
	for (const name of layerHeld) {
		mandatory.push(name);
	}
	for (const name of modifierNames(variation.held)) {
		mandatory.push(name);
	}
	const from = jsonObject(
		["key_code", "modifiers"],
		[jsonString(keyCode(map.from)), jsonObject(["mandatory"], [strings(mandatory)])],
	);
	const to = variation.send.isEmpty()
		? keyCodeOnly(map.to)
		: jsonObject(
			["key_code", "modifiers"],
			[jsonString(keyCode(map.to)), strings(modifierNames(variation.send))],
		);
	return jsonObject(["from", "to", "type"], [from, to, jsonString("basic")]);
}

function ruleJson(title: string, manipulators: JsonValue[]): JsonValue {
	return jsonObject(
		["description", "manipulators"],
		[jsonString(title), jsonArray(manipulators)],
	);
}

function groupJson(this group: RuleGroup): JsonValue {
	const manipulators: JsonValue[] = [];
	for (const map of group.maps) {
		for (const variation of map.variations) {
			manipulators.push(map.variationManipulator(variation));
		}
	}
	return ruleJson(group.title, manipulators);
}

export function karabinerJson(this geek: GeekCaps): string {
	const layerRule: JsonValue[] = [geek.layer.layerManipulator()];
	for (const remap of geek.remaps) {
		layerRule.push(remap.remapManipulator());
	}
	const rules: JsonValue[] = [ruleJson(layerTitle, layerRule)];
	for (const group of geek.groups) {
		rules.push(group.groupJson());
	}
	const document = jsonObject(
		["title", "author", "homepage", "hostpage", "manual", "import_url", "rules"],
		[
			jsonString("GeekCaps Enhancement"),
			jsonString("Cloud Le (lehaoson@gmail.com)"),
			jsonString("https://github.com/cloudle/geekCaps"),
			jsonString("https://pqrs.org/osx/karabiner/complex_modifications/"),
			jsonString("https://github.com/cloudle/geekCaps/blob/master/exports/"),
			jsonString(importPrefix + exportUrl),
			jsonArray(rules),
		],
	);
	return stringifyPretty(document, 2);
}
