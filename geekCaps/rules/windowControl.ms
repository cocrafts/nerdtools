import { Key, RuleGroup, cmd, fn, none, opt, shift } from "../layout";

export const windowControl: RuleGroup = {
	title: "Geek Window Control",
	maps: [
		{
			from: Key.Tab,
			to: Key.Tab,
			variations: [
				{ held: none, send: cmd },
				{ held: cmd, send: cmd | shift },
			],
		},
		{ from: Key.Q, to: Key.Grave, variations: [{ held: none, send: cmd }] },
		{ from: Key.Q, to: Key.Escape, variations: [{ held: cmd, send: cmd | shift | opt }] },
		{ from: Key.A, to: Key.F11, variations: [{ held: none, send: none }] },
		{ from: Key.A, to: Key.F4, variations: [{ held: cmd, send: fn }] },
	],
};
