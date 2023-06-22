local wezterm = require("wezterm")

local config = {}
local colors = {
	fg = "#ABB2BF",
	bg = "#1A1B26",
	dark = "#16161e",
	darker = "#0c0c0f",
}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.initial_rows = 50
config.initial_cols = 100

config.color_scheme = "tokyonight_night"
config.font_size = 14.4
config.font = wezterm.font {
	family = "OperatorMonoLig Nerd Font Mono",
	weight = "Book",
}

config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.enable_tab_bar = false
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

return config
