local globals = {
	mapleader = " ",
	localmapleader = " ",
	zig_fmt_autosave = 0,
}

local opts = {
	timeout = true,
	timeoutlen = 100, -- time to wait for mapped sequence to complete
	-- utilities
	title = true, -- show buffer name in window title
	undofile = true, -- enable persistent undo
	cursorline = true, -- highlight current line
	hlsearch = true, -- highlight all matches on previous search pattern
	incsearch = true,
	ignorecase = true, -- ignore case when search
	smartcase = true,
	mouse = "a",
	-- line numbers
	number = true, -- show line numbers
	relativenumber = true, -- show relative numbers
	numberwidth = 3,
	termguicolors = true,
	-- invisible characters
	list = true,
	listchars = {
		tab = " ",
		eol = "¬",
		space = "·",
	},
}

local defer_opts = {
	-- use tab
	autoindent = true,
	tabstop = 4, -- insert 2 spaces for a tab
	shiftwidth = 4, -- number of spaces inserted for each indentation
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

if vim.g.neovide then
	vim.opt.guifont = "Operator Mono Lig:h13.8"
	vim.opt.linespace = 4
	vim.g.neovide_profiler = false

	vim.g.neovide_remember_window_size = true
	vim.g.neovide_cursor_vfx_mode = "pixiedust"
	vim.g.neovide_cursor_vfx_particle_lifetime = 4.0
	vim.g.neovide_cursor_vfx_particle_density = 21.0
	vim.g.neovide_scroll_animation_far_lines = 0
end

-- -- undercurl for Wezterm
-- vim.api.nvim_set_option_value("t_Cs", "\27[4:3m")
-- vim.api.nvim_set_option_value("t_Ce", "\27[4:0m")
