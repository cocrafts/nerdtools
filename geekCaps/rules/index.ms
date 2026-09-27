import { GeekCaps, Key } from "../layout";
import { developer } from "./developer";
import { misc } from "./misc";
import { navigation } from "./navigation";
import { shifter } from "./shifter";
import { windowControl } from "./windowControl";

export const geekCaps: GeekCaps = {
	layer: { key: Key.LeftControl, tap: Key.Escape },
	macRemaps: [{ from: Key.RightCommand, to: Key.RightControl }],
	pcRemaps: [
		{ from: Key.LeftCommand, to: Key.LeftControl },
		{ from: Key.LeftOption, to: Key.LeftCommand },
		{ from: Key.RightCommand, to: Key.LeftOption },
		{ from: Key.RightOption, to: Key.RightCommand },
	],
	groups: [misc, navigation, shifter, windowControl, developer],
};
