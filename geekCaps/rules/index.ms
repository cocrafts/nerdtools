import { GeekCaps, Key } from "../layout";
import { developer } from "./developer";
import { misc } from "./misc";
import { navigation } from "./navigation";
import { shifter } from "./shifter";
import { windowControl } from "./windowControl";

export const geekCaps: GeekCaps = {
	layer: { key: Key.CapsLock, tap: Key.Escape },
	remaps: [{ from: Key.RightCommand, to: Key.RightControl }],
	groups: [misc, navigation, shifter, windowControl, developer],
};
