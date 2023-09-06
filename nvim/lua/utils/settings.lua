local globals = {
	mapleader = " ",
	localmapleader = " ",
	neovide_cursor_vfx_mode = "pixiedust",
	neovide_remember_window_size = true,
	gitblame_highlight_group = "GitBlame",
	gitblame_date_format = "%r",
	gitblame_message_template = " <author>, <date> • <summary> ",
	gitblame_message_when_not_committed = "",
}

local opts = {
	spell = true,
	spelllang = "en_us",
	guifont = "OperatorMonoLig Nerd Font Mono:h13.8",
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
	-- utilities
	title = true,     -- show buffer name in window title
	undofile = true,  -- enable persistent undo
	cursorline = true, -- highlight current line
	hlsearch = true,  -- highlight all matches on previous search pattern
	incsearch = true,
	ignorecase = true, -- ignore case when search
	smartcase = true,
	mouse = "a",
	-- line numbers
	number = true,        -- show line numbers
	relativenumber = true, -- show relative numbers
	numberwidth = 3,
	termguicolors = true,
	-- invisible characters
	list = true,
	listchars = {
		tab = " ",
		eol = "¬",
		space = "·",
	},
}

if vim.g.neovide then
	opts["linespace"] = 4
end

local defer_opts = {
	-- use tab
	autoindent = true,
	tabstop = 2,   -- insert 2 spaces for a tab
	shiftwidth = 2, -- number of spaces inserted for each indentation
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
	end
end, 0)

-- undercurl for Wezterm
vim.api.nvim_set_option("t_Cs", "\27[4:3m")
vim.api.nvim_set_option("t_Ce", "\27[4:0m")
