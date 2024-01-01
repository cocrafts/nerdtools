local utils = require("themes.utils")
local theme = require("utils.config").theme
local highlight = theme.options.highlight
local colors = theme.colors

theme.configure()
vim.cmd("colorscheme " .. theme.options.variant)

highlight.lsp = {
	LspInlayHint = { fg = colors.gray, bg = colors.none },
	NormalFloat = { bg = colors.bg },
	FloatBorder = { fg = colors.float_border, bg = colors.bg },
}

highlight.gui = {
	BlameLine = { fg = colors.comments, bg = colors.cursor },
	CursorLine = { bg = colors.cursor },
	MsgArea = { fg = colors.fg, bg = colors.bg },

	Normal = { bg = colors.bg },
	LineNR = { fg = colors.dim }, -- line numbers
	CursorLineNR = { fg = colors.blue }, -- current line number
	NormalMode = { fg = colors.blue },
	InsertMode = { fg = colors.green },
	VisualMode = { fg = colors.purple },
	CommandMode = { fg = colors.types },
	ReplaceMode = { fg = colors.red },
	SelectMode = { fg = colors.purple },

	ScrollView = { bg = colors.fg },

	NonText = { fg = colors.gray }, -- whitespaces
	SpecialKey = { fg = colors.gray }, -- whitespaces
	Whitespace = { fg = colors.gray }, -- whitespaces
	Search = { fg = colors.darkest, bg = colors.blue },
}

highlight.hi = {
	Comment = { fg = colors.comments, style = "italic" },

	luaFunction = { fg = colors.keywords },

	rustMacro = { fg = colors.functions },
	rustStorage = { fg = colors.keywords, style = "italic" },
	rustModPathSep = { fg = colors.fg },
}

highlight.system = {
	PanelHeading = { bg = colors.buffer_bg },
	BufferLineFill = { bg = colors.explorer_bg },
	-- BufferLineSeparator = { ... },
	-- BufferLineSeparatorVisible = { ... },

	NeoTreeNormal = { bg = colors.explorer_bg },
	NeoTreeNormalNC = { bg = colors.explorer_bg },
	NeoTreeEndOfBuffer = { fg = colors.explorer_bg },
	NeoTreeWinSeparator = { fg = colors.explorer_bg, bg = colors.explorer_bg },
	NeoTreeDirectoryName = { fg = colors.white },
	-- git file name
	NeoTreeGitAdded = { fg = colors.types, style = "bold" },
	NeoTreeGitConflict = { fg = colors.red, style = "bold" },
	NeoTreeGitDeleted = { fg = colors.comments, style = "bold" },
	NeoTreeGitIgnored = { fg = colors.gray, style = "bold" },
	NeoTreeGitModified = { fg = colors.blue, style = "bold" },
	NeoTreeGitUntracked = { fg = colors.green, style = "bold" },
	-- git symbol
	NeoTreeGitStaged = { fg = colors.gray, style = "bold" },
	NeoTreeGitUnstaged = { fg = colors.green, style = "bold" },

	-- Telescope
	TelescopeNormal = { bg = colors.bg },
	TelescopeBorder = { bg = colors.bg, fg = colors.float_border },

	-- Cmp
	CmpNormal = { bg = colors.bg },
	CmpFloatBorder = { bg = colors.bg, fg = colors.float_border },
	CmpCursorLine = { bg = colors.cursor },

	-- Gitsign
	GitSignsAdd = { fg = colors.green },
	GitSignsChange = { fg = colors.blue },

	-- IndentBlanklineContextChar = { fg = colors.fg },
	IndentBlanklineIndent = { fg = colors.dim },
	IndentBlanklineIndent1 = { fg = "#E06C75" },
	IndentBlanklineIndent2 = { fg = "#E5C07B" },
	IndentBlanklineIndent3 = { fg = "#98C379" },
	IndentBlanklineIndent4 = { fg = "#56B6C2" },
	IndentBlanklineIndent5 = { fg = "#61AFEF" },
	IndentBlanklineIndent6 = { fg = "#C678DD" },
}

for _, group in pairs(highlight) do
	utils.initialize(group)
end

-- vim.api.nvim_command "hi clear"

-- if vim.fn.exists "syntax_on" then
-- 	vim.api.nvim_command "syntax reset"
-- end
