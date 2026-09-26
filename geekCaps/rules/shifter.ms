import { Key, RuleGroup, Variation, none, shift } from "../layout";

const shifted: Variation[] = [{ held: none, send: shift }];

export const shifter: RuleGroup = {
	title: "Geek Shifter",
	maps: [
		{ from: Key.Num1, to: Key.Num1, variations: shifted },
		{ from: Key.Num2, to: Key.Num2, variations: shifted },
		{ from: Key.Num3, to: Key.Num3, variations: shifted },
		{ from: Key.Num4, to: Key.Num4, variations: shifted },
		{ from: Key.Num5, to: Key.Num5, variations: shifted },
		{ from: Key.Num6, to: Key.Num6, variations: shifted },
		{ from: Key.Num7, to: Key.Num7, variations: shifted },
		{ from: Key.Num8, to: Key.Num8, variations: shifted },
		{ from: Key.Num9, to: Key.Num9, variations: shifted },
		{ from: Key.Num0, to: Key.Num0, variations: shifted },
		{ from: Key.Hyphen, to: Key.Hyphen, variations: shifted },
		{ from: Key.EqualSign, to: Key.EqualSign, variations: shifted },
		{ from: Key.Backslash, to: Key.Backslash, variations: shifted },
	],
};
