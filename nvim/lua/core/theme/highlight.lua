local colors = require("core.theme.colors")

return {
	CursorLine = { bg = colors.cursor },
	GitBlame = { fg = "#434A68", bg = colors.cursor },
	MsgArea = { fg = colors.fg, bg = colors.bg },

	LineNR = { fg = colors.dim }, -- line numbers
	CursorLineNR = { fg = colors.blue }, -- current line number
	NormalMode = { fg = colors.blue },
	InsertMode = { fg = colors.green },
	VisualMode = { fg = colors.purple },
	CommandMode = { fg = colors.types },
	ReplaceMode = { fg = colors.red },
	SelectMode = { fg = colors.purple },

	MatchParen = { fg = colors.bg, bg = colors.fg },
	NvimTreeEndOfBuffer = { fg = colors.darkest, bg = colors.darkest }, -- space under the file tree 
	FidgetTitle = { fg = colors.blue },

	NonText = { fg = colors.gray },   -- whitespaces
	SpecialKey = { fg = colors.gray }, -- whitespaces
	Whitespace = { fg = colors.dim }, -- whitespaces
	Search = { fg = colors.darkest, bg = colors.blue },

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
