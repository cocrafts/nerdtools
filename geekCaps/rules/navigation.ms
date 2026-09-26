import { Key, RuleGroup, Variation, cmd, ctrl, none, opt, shift } from "../layout";

const arrows: Variation[] = [
	{ held: none, send: none },
	{ held: cmd, send: shift },
	{ held: shift, send: opt },
	{ held: cmd | shift, send: opt | shift },
];

const lineEdge: Variation[] = [
	{ held: none, send: cmd },
	{ held: cmd, send: shift | cmd },
];

const tabSwitch: Variation[] = [{ held: shift, send: ctrl | shift }];

export const navigation: RuleGroup = {
	title: "Geek Navigation",
	maps: [
		{ from: Key.H, to: Key.LeftArrow, variations: arrows },
		{ from: Key.J, to: Key.DownArrow, variations: arrows },
		{ from: Key.L, to: Key.RightArrow, variations: arrows },
		{ from: Key.K, to: Key.UpArrow, variations: arrows },
		{ from: Key.U, to: Key.LeftArrow, variations: lineEdge },
		{ from: Key.P, to: Key.RightArrow, variations: lineEdge },
		{ from: Key.U, to: Key.Tab, variations: tabSwitch },
		{ from: Key.P, to: Key.Tab, variations: tabSwitch },
	],
};
