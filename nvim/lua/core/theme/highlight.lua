local colors = require("core.theme.colors")

return {
	NonText = { fg = colors.dim },   -- whitespaces
	SpecialKey = { fg = colors.dim }, -- whitespaces
	Whitespace = { fg = colors.dim }, -- whitespaces
	Keyword = { fg = colors.keywords },
	Comment = { fg = colors.comments, style = "italic" },
	Number = { fg = colors.numbers },
	Function = { fg = colors.functions },
	Identifier = { fg = colors.variables },
	String = { fg = colors.strings, style = "italic" },
	Type = { fg = colors.types },
	IndentBlanklineIndent = { fg = colors.dim },
	IndentBlanklineIndent1 = { fg = "#E06C75" },
	IndentBlanklineIndent2 = { fg = "#E5C07B" },
	IndentBlanklineIndent3 = { fg = "#98C379" },
	IndentBlanklineIndent4 = { fg = "#56B6C2" },
	IndentBlanklineIndent5 = { fg = "#61AFEF" },
	IndentBlanklineIndent6 = { fg = "#C678DD" },
}
