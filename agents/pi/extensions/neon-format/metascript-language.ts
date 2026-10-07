import type { LanguageFn } from "highlight.js";

export const metascriptLanguage: LanguageFn = hljs => ({
	name: "MetaScript",
	aliases: ["ms", "msc", "cms"],
	keywords: {
		keyword:
			"if else for while do return break continue switch case default try catch finally throw " +
			"class interface function const let var type enum struct union " +
			"async await static public private protected readonly abstract override export import from as extends implements new " +
			"typeof instanceof in of is keyof move borrow copy own macro extern defer distinct",
		built_in:
			"void bool i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f32 f64 usize isize char string any never unknown number boolean " +
			"Array Map Set Promise Result Option Error String Buffer Slice Range",
		literal: "true false null undefined nil this self super",
	},
	contains: [
		hljs.C_LINE_COMMENT_MODE,
		hljs.C_BLOCK_COMMENT_MODE,
		{
			scope: "meta",
			begin: "@",
			end: "\\b",
			keywords: {
				meta: "cImport cimport jsImport erlImport external inline deprecated target comptime emit sizeof alignof typeinfo currentTarget native library include extern derive serialize test benchmark packed align bitcast runtime",
			},
		},
		{
			scope: "title.function",
			begin: "\\b(function|macro)\\s+",
			end: "\\s*(?=\\(|<)",
			keywords: "function macro",
			contains: [{ scope: "title", begin: "[a-zA-Z_][a-zA-Z0-9_]*" }],
		},
		{
			scope: "title.class",
			begin: "\\b(class|interface|type|enum)\\s+",
			end: "\\s*(?=[{<]| extends| implements)",
			keywords: "class interface type enum",
			contains: [{ scope: "title", begin: "[A-Z][a-zA-Z0-9_]*" }],
		},
		{
			scope: "string",
			variants: [
				{ begin: '"', end: '"', contains: [{ begin: "\\\\.", scope: "char.escape" }] },
				{ begin: "'", end: "'", contains: [{ begin: "\\\\.", scope: "char.escape" }] },
				{
					begin: "`",
					end: "`",
					contains: [
						{ begin: "\\\\.", scope: "char.escape" },
						{ begin: "\\$\\{", end: "\\}", contains: ["self"], scope: "subst" },
					],
				},
			],
		},
		{
			scope: "number",
			variants: [
				{ begin: "\\b0[xX][0-9a-fA-F][0-9a-fA-F_]*\\b" },
				{ begin: "\\b0[bB][01][01_]*\\b" },
				{ begin: "\\b0[oO][0-7][0-7_]*\\b" },
				{ begin: "\\b[0-9][0-9_]*\\.[0-9][0-9_]*([eE][+-]?[0-9][0-9_]*)?\\b" },
				{ begin: "\\b[0-9][0-9_]*\\b" },
			],
		},
		{
			scope: "operator",
			begin: /(\+\+|--|\+=|-=|\*=|\/=|%=|&=|\|=|\^=|<<=|>>=|===|!==|==|!=|<=|>=|<|>|&&|\|\||!|\?\?|\+|-|\*|\/|%|\*\*|&|\||\^|~|<<|>>|\.\.\.|\?|:|=>)/,
		},
	],
});
