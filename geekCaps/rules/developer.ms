import { Key, RuleGroup, Variation, cmd, ctrl, none, shift } from "../layout";

const plainOrShifted: Variation[] = [
	{ held: none, send: none },
	{ held: cmd, send: shift },
];

const bracket: Variation[] = [
	{ held: cmd, send: none },
	{ held: shift, send: shift },
];

const shifted: Variation[] = [{ held: none, send: shift }];
const cmdShifted: Variation[] = [{ held: cmd, send: shift }];

export const developer: RuleGroup = {
	title: "Geek Developer",
	maps: [
		{ from: Key.Escape, to: Key.Grave, variations: plainOrShifted },
		{ from: Key.Backspace, to: Key.DeleteForward, variations: [{ held: none, send: none }] },
		{ from: Key.S, to: Key.S, variations: [{ held: none, send: cmd }] },
		{ from: Key.Spacebar, to: Key.Spacebar, variations: [{ held: none, send: ctrl }] },
		{ from: Key.Quote, to: Key.EqualSign, variations: plainOrShifted },
		{ from: Key.Semicolon, to: Key.Hyphen, variations: plainOrShifted },
		{ from: Key.I, to: Key.OpenBracket, variations: bracket },
		{ from: Key.O, to: Key.CloseBracket, variations: bracket },
		{ from: Key.I, to: Key.Num9, variations: shifted },
		{ from: Key.O, to: Key.Num0, variations: shifted },
		{ from: Key.Comma, to: Key.Comma, variations: shifted },
		{ from: Key.Period, to: Key.Period, variations: shifted },
		{ from: Key.OpenBracket, to: Key.Backslash, variations: shifted },
		{ from: Key.Comma, to: Key.Num5, variations: cmdShifted },
		{ from: Key.Period, to: Key.Num6, variations: cmdShifted },
		{ from: Key.Slash, to: Key.Num7, variations: cmdShifted },
		{ from: Key.Slash, to: Key.Slash, variations: shifted },
	],
};
