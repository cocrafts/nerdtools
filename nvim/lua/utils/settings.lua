local globals = {
	mapleader = ' ',
	localmapleader = ' ',
}

local opts = {
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
	-- use tab
	autoindent = true,
	expandtab = true, -- convert tabs to spaces
	tabstop = 2,      -- insert 2 spaces for a tab
	shiftwidth = 2,   -- number of spaces inserted for each indentation
	-- utilities
	title = true,     -- show buffer name in window title
	undofile = true,  -- enable persistent undo
	cursorline = true, -- highlight current line
	hlsearch = false, -- highlight all matches on previous search pattern
	incsearch = true,
	ignorecase = true, -- ignore case when search
	smartcase = true,
	mouse = "a",
	-- line numbers
	number = true,        -- show line numbers
	relativenumber = true, -- show relative numbers
	numberwidth = 3,

	list = true,
	listchars = {
		tab = "--",
		eol = "¬",
		space = "·",
	},
}

for k, v in pairs(globals) do
	vim.g[k] = v
end

for k, v in pairs(opts) do
	vim.opt[k] = v
end

return opts
