import { Key, RuleGroup, Variation, cmd, ctrl, none, opt, shift } from "../layout";

const ctrlHeld: Variation[] = [{ held: none, send: ctrl }];

export const misc: RuleGroup = {
	title: "Geek Misc",
	maps: [
		{ from: Key.Z, to: Key.Z, variations: ctrlHeld },
		{ from: Key.X, to: Key.X, variations: ctrlHeld },
		{ from: Key.C, to: Key.C, variations: ctrlHeld },
		{ from: Key.V, to: Key.V, variations: ctrlHeld },
		{ from: Key.B, to: Key.B, variations: ctrlHeld },
		{ from: Key.D, to: Key.D, variations: ctrlHeld },
		{
			from: Key.N,
			to: Key.Backspace,
			variations: [
				{ held: none, send: opt },
				{ held: shift, send: opt },
				{ held: cmd, send: opt },
			],
		},
		{
			from: Key.M,
			to: Key.Backspace,
			variations: [
				{ held: none, send: none },
				{ held: shift, send: none },
				{ held: cmd, send: none },
				{ held: opt, send: none },
			],
		},
	],
};
