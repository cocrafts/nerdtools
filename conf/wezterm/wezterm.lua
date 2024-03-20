local wezterm = require("wezterm")
local act = wezterm.action

local config = {}
local colors = {
	fg = "#ABB2BF",
	bg = "#1A1B26",
	split = "#333333",
	dark = "#16161e",
	darker = "#0c0c0f",
	cursor = "#C0CAF7",
}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.color_scheme = "tokyonight_night"

-- https://wezfurlong.org/wezterm/config/lua/wezterm/target_triple.html
if wezterm.target_triple == "x86_64-unknown-linux-gnu" then
	config.font_size = 11.5
	config.line_height = 1.1

	config.initial_rows = 70
	config.initial_cols = 150
else
	config.font_size = 14.5
	config.line_height = 1.2

	config.initial_rows = 50
	config.initial_cols = 100
end

config.font = wezterm.font_with_fallback({
	{
		family = "Operator Mono Lig",
		weight = "Book",
	},
	{
		family = "Symbols Nerd Font Mono",
		scale = 0.6,
	},
})

config.front_end = "WebGpu"
config.force_reverse_video_cursor = false
config.adjust_window_size_when_changing_font_size = false
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

config.keys = {
	{
		key = "k",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(act.SendKey({ key = "l", mods = "CTRL" }), pane)
			else
				window:perform_action(act.ClearScrollback("ScrollbackAndViewport"), pane)
			end
		end),
	},
	{
		key = "I",
		mods = "CMD|SHIFT",
		action = act.SplitPane({
			direction = "Up",
			size = { Percent = 24 },
		}),
	},
	{
		key = "J",
		mods = "CMD|SHIFT",
		action = act.SplitPane({
			direction = "Down",
			size = { Percent = 24 },
		}),
	},
	{
		key = "H",
		mods = "CMD|SHIFT",
		action = act.SplitPane({
			direction = "Left",
			size = { Percent = 36 },
		}),
	},
	{
		key = "L",
		mods = "CMD|SHIFT",
		action = act.SplitPane({
			direction = "Right",
			size = { Percent = 36 },
		}),
	},
	{
		key = "O",
		mods = "CMD|SHIFT",
		action = act.PaneSelect({}),
	},
	{
		key = "o",
		mods = "CMD",
		action = act.ActivatePaneDirection("Next"),
	},
	{
		key = "w",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = false }),
	},
	{
		key = "N",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(_, pane)
			pane:move_to_new_window()
		end),
	},
	{
		key = "s",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(act.Multiple({ act.SendKey({ key = " " }), act.SendKey({ key = "w" }) }), pane)
			else
				window:perform_action(act.SendKey({ key = "s", mods = "CMD" }), pane)
			end
		end),
	},
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(
					act.Multiple({
						act.SendKey({ key = "y" }),
						act.SendKey({ key = "y" }),
						act.SendKey({ key = "p" }),
					}),
					pane
				)
			end
		end),
	},
	{
		key = "/",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(
					act.Multiple({
						act.SendKey({ key = "g" }),
						act.SendKey({ key = "c" }),
						act.SendKey({ key = "c" }),
						act.SendKey({ key = "j" }),
					}),
					pane
				)
			end
		end),
	},
	{
		key = "LeftArrow",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then
				local prev_buffer_action = act.Multiple({
					act.SendKey({ key = " " }),
					act.SendKey({ key = "b" }),
					act.SendKey({ key = "p" }),
				})
				window:perform_action(prev_buffer_action, pane)
			end
		end),
	},
	{
		key = "RightArrow",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then
				local next_buffer_action = act.Multiple({
					act.SendKey({ key = " " }),
					act.SendKey({ key = "b" }),
					act.SendKey({ key = "n" }),
				})
				window:perform_action(next_buffer_action, pane)
			end
		end),
	},
}

config.colors = {
	cursor_bg = colors.cursor,
	cursor_fg = colors.darker,
	cursor_border = colors.cursor,
	split = colors.split,
}

return config
