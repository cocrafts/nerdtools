local globals = {
	mapleader = ' ',
	localmapleader = ' ',
}

local opts = {
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
	-- use tab
	expandtab = true, -- convert tabs to spaces
	shiftwidth = 2,  -- number of spaces inserted for each indentation
	tabstop = 2,     -- insert 2 spaces for a tab
	smartindent = true,
	-- utilities
	title = true,     -- show buffer name in window title
	undofile = true,  -- enable persistent undo
	cursorline = true, -- highlight current line
	hlsearch = true,  -- highlight all matches on previous search pattern
	ignorecase = true, -- ignore case when search
	smartcase = true,
	mouse = "a",
	-- line numbers
	number = true,        -- show line numbers
	relativenumber = true, -- show relative numbers
	numberwidth = 4,
}

for k, v in pairs(globals) do
	vim.g[k] = v
end

for k, v in pairs(opts) do
	vim.opt[k] = v
end

return opts
