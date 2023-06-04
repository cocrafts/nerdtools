local colors = require("core.theme.colors")

return {
	NonText = { fg = colors.gray },   -- whitespaces
	SpecialKey = { fg = colors.gray }, -- whitespaces
	Whitespace = { fg = colors.gray }, -- whitespaces
	FidgetTitle = { fg = colors.blue },

	Keyword = { fg = colors.keywords },
	Comment = { fg = colors.comments, style = "italic" },
	Number = { fg = colors.numbers },
	Function = { fg = colors.functions },
	Identifier = { fg = colors.variables },
	Statement = { fg = colors.keywords },
	String = { fg = colors.strings },
	Type = { fg = colors.types },
	PreProc = { fg = colors.procs },
	Special = { fg = colors.functions },

	luaFunction = { fg = colors.keywords },

	rustMacro = { fg = colors.functions },
	rustStorage = { fg = colors.keywords, style = "italic" },
	rustModPathSep = { fg = colors.fg },

	IndentBlanklineIndent = { fg = colors.dim },
	IndentBlanklineIndent1 = { fg = "#E06C75" },
	IndentBlanklineIndent2 = { fg = "#E5C07B" },
	IndentBlanklineIndent3 = { fg = "#98C379" },
	IndentBlanklineIndent4 = { fg = "#56B6C2" },
	IndentBlanklineIndent5 = { fg = "#61AFEF" },
	IndentBlanklineIndent6 = { fg = "#C678DD" },
}
