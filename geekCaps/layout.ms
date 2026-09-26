export enum Key {
	Num0,
	Num1,
	Num2,
	Num3,
	Num4,
	Num5,
	Num6,
	Num7,
	Num8,
	Num9,
	A,
	B,
	C,
	D,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	S,
	U,
	V,
	X,
	Z,
	F4,
	F11,
	Backslash,
	Backspace,
	CapsLock,
	CloseBracket,
	Comma,
	DeleteForward,
	DownArrow,
	EqualSign,
	Escape,
	Grave,
	Hyphen,
	LeftArrow,
	OpenBracket,
	Period,
	Quote,
	RightArrow,
	RightCommand,
	RightControl,
	Semicolon,
	Slash,
	Spacebar,
	Tab,
	UpArrow,
}

export enum Mod {
	Cmd,
	Opt,
	Ctrl,
	Shift,
	Fn,
}

export const none = 0 as BitSet<Mod>;
export const cmd = none.incl(Mod.Cmd);
export const opt = none.incl(Mod.Opt);
export const ctrl = none.incl(Mod.Ctrl);
export const shift = none.incl(Mod.Shift);
export const fn = none.incl(Mod.Fn);

export struct Variation {
	held: BitSet<Mod>;
	send: BitSet<Mod>;
}

export struct KeyMap {
	from: Key;
	to: Key;
	variations: Variation[];
}

export struct RuleGroup {
	title: string;
	maps: KeyMap[];
}

export struct Layer {
	key: Key;
	tap: Key;
}

export struct Remap {
	from: Key;
	to: Key;
}

export struct GeekCaps {
	layer: Layer;
	remaps: Remap[];
	groups: RuleGroup[];
}
