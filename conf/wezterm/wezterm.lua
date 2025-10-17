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

-- Dim inactive panes
config.inactive_pane_hsb = {
	hue = 1.0,
	saturation = 1.0,
	brightness = 0.6,
}

-- Image protocol support for image.nvim
-- WezTerm supports both Kitty and iTerm2 protocols
config.term = "wezterm" -- Use WezTerm's terminfo for accurate capabilities

-- https://wezfurlong.org/wezterm/config/lua/wezterm/target_triple.html
if wezterm.target_triple == "x86_64-unknown-linux-gnu" then
	config.font_size = 11.5
	config.line_height = 1.2

	config.initial_rows = 70
	config.initial_cols = 150
else
	config.font_size = 14.5
	config.line_height = 1.14

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

config.max_fps = 120
config.front_end = "WebGpu"
config.force_reverse_video_cursor = true
config.adjust_window_size_when_changing_font_size = false
config.use_resize_increments = false
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

-- Platform-specific modifier key
local mod = "CMD"
if wezterm.target_triple == "x86_64-unknown-linux-gnu" then
	mod = "CTRL"
end

config.keys = {
	{
		key = "k",
		mods = mod,
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(act.Multiple({ act.SendKey({ key = " " }), act.SendKey({ key = "K" }) }), pane)
			else
				window:perform_action(act.ClearScrollback("ScrollbackAndViewport"), pane)
			end
		end),
	},
	{
		key = "I",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Up",
			size = { Percent = 24 },
		}),
	},
	{
		key = "J",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Down",
			size = { Percent = 24 },
		}),
	},
	{
		key = "H",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Left",
			size = { Percent = 32 },
		}),
	},
	{
		key = "L",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Right",
			size = { Percent = 32 },
		}),
	},
	-- Resize panes
	{
		key = "H",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "J",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Down", 5 }),
	},
	{
		key = "K",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Up", 5 }),
	},
	{
		key = "L",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Right", 5 }),
	},
	{
		key = "O",
		mods = mod .. "|SHIFT",
		action = act.PaneSelect({}),
	},
	{
		key = "o",
		mods = mod,
		action = act.ActivatePaneDirection("Next"),
	},
	{
		key = "l",
		mods = mod,
		action = wezterm.action_callback(function(window)
			local tab = window:active_tab()
			local panes = tab:panes_with_info()
			if #panes > 0 then
				panes[#panes].pane:activate()
			end
		end),
	},
	{
		key = "j",
		mods = mod,
		action = wezterm.action_callback(function(window)
			local tab = window:active_tab()
			local panes = tab:panes()
			if panes[1] then
				panes[1]:activate()
			end
		end),
	},
	{
		key = "i",
		mods = mod,
		action = wezterm.action_callback(function(window, pane)
			local tab = window:active_tab()
			local panes = tab:panes()
			local claude_pane = nil

			for _, p in ipairs(panes) do
				local title = p:get_title()
				if string.find(title, "✳") or title == "claude" then
					claude_pane = p
					break
				end
			end

			if claude_pane and claude_pane:pane_id() ~= pane:pane_id() then
				claude_pane:activate()
			else
				panes[2]:activate()
			end
		end),
	},
	{
		key = "w",
		mods = mod,
		action = act.CloseCurrentPane({ confirm = false }),
	},
	{
		key = "N",
		mods = mod .. "|SHIFT",
		action = wezterm.action_callback(function(_, pane)
			pane:move_to_new_window()
		end),
	},
	{
		key = "s",
		mods = mod,
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then -- detect application like Vim
				window:perform_action(act.Multiple({ act.SendKey({ key = " " }), act.SendKey({ key = "w" }) }), pane)
			else
				window:perform_action(act.SendKey({ key = "s", mods = mod }), pane)
			end
		end),
	},
	{
		key = "d",
		mods = mod,
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
		mods = mod,
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
		mods = mod .. "|SHIFT",
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
		mods = mod .. "|SHIFT",
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
	{
		key = "z",
		mods = "CTRL",
		action = wezterm.action.TogglePaneZoomState,
	},
	{
		key = "o",
		mods = "CTRL",
		action = wezterm.action.RotatePanes("Clockwise"),
	},
	{
		key = "O",
		mods = "CTRL",
		action = wezterm.action.RotatePanes("CounterClockwise"),
	},
	{
		key = ";",
		mods = mod,
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then
				window:perform_action(act.SendKey({ key = ";", mods = "CTRL" }), pane)
			else
				window:perform_action(act.SendKey({ key = ";", mods = mod }), pane)
			end
		end),
	},
	{
		key = "Tab",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane)
			if pane:is_alt_screen_active() then
				local next_buffer_action = act.Multiple({
					act.SendKey({ key = "g" }),
					act.SendKey({ key = "t" }),
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
