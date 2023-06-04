local globals = {
	mapleader = " ",
	localmapleader = " ",
	gitblame_message_template = "<author> • <date> • <summary> ",
	gitblame_message_when_not_committed = "Let the world know about this! ",
}

local opts = {
	guifont = "OperatorMonoLig Nerd Font Mono:h14",
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
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

local defer_opts = {
	-- use tab
	autoindent = true,
	tabstop = 2,     -- insert 2 spaces for a tab
	shiftwidth = 2,  -- number of spaces inserted for each indentation
}

for k, v in pairs(globals) do
	vim.g[k] = v
end

for k, v in pairs(opts) do
	vim.opt[k] = v
end

vim.defer_fn(function()
	for k, v in pairs(defer_opts) do
		vim.opt[k] = v
	end --
end, 0)

return opts
