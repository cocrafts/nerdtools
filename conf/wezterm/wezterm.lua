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
if wezterm.target_triple == "x86_64-unknown-linux-gnu" or wezterm.target_triple:find("windows") then
	config.font_size = 11
	config.line_height = 1.1

	config.initial_rows = 70
	config.initial_cols = 150
else
	config.font_size = 14.5
	config.line_height = 1.24

	config.initial_rows = 50
	config.initial_cols = 100
end

-- On Windows, open straight into PowerShell 7 (falls back handled by pwsh install)
if wezterm.target_triple:find("windows") then
	config.default_prog = { "pwsh.exe", "-NoLogo" }
end

-- Operator Mono Lig ships four faces: Book / Medium, each with an Italic.
-- Named weights resolve on CoreText/fontconfig, but Windows/DirectWrite reports
-- skewed numeric weights ("Book" -> 325, "Medium" -> 350), so match by number
-- there. Operator has no true Bold face, so bold text uses the Medium face.
local op_regular, op_bold = "Book", "Medium"
if wezterm.target_triple:find("windows") then
	op_regular, op_bold = 325, 350
end

-- Operator-Mono-first stack for a given weight + style. JetBrains Mono is the
-- fallback only when Operator lacks a glyph (e.g. some Nerd symbols).
local function operator_font(weight, style)
	return wezterm.font_with_fallback({
		{ family = "Operator Mono Lig",      weight = weight,                                  style = style },
		{ family = "JetBrains Mono",         weight = (weight == op_bold) and "Bold" or "Regular", style = style },
		{ family = "Symbols Nerd Font Mono", scale = 0.6 },
	})
end

config.font = operator_font(op_regular, "Normal")

-- One rule per intensity/italic combination so no variant slips to the fallback
-- font. (Normal + upright is config.font above.)
config.font_rules = {
	{ italic = true,  intensity = "Normal", font = operator_font(op_regular, "Italic") },
	{ italic = false, intensity = "Half",   font = operator_font(op_regular, "Normal") },
	{ italic = true,  intensity = "Half",   font = operator_font(op_regular, "Italic") },
	{ italic = false, intensity = "Bold",   font = operator_font(op_bold, "Normal") },
	{ italic = true,  intensity = "Bold",   font = operator_font(op_bold, "Italic") },
}

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
if wezterm.target_triple == "x86_64-unknown-linux-gnu" or wezterm.target_triple:find("windows") then
	mod = "CTRL"
end

-- When `mod` is CTRL (Windows/Linux), the standalone CTRL rotate bindings below
-- would collide with mod-bindings (e.g. CTRL+o = next pane). Shift them to CTRL+ALT
-- there. On macOS (mod=CMD) they stay on plain CTRL, unchanged.
local rotmod = "CTRL"
if mod == "CTRL" then
	rotmod = "CTRL|ALT"
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
		key = "J",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Down",
			size = { Percent = 24 },
		}),
	},
	{
		key = "K",
		mods = mod .. "|SHIFT",
		action = act.SplitPane({
			direction = "Up",
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
	-- Layout switching
	{
		key = "h",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "j",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Down", 5 }),
	},
	{
		key = "k",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Up", 5 }),
	},
	{
		key = "l",
		mods = mod .. "|ALT",
		action = act.AdjustPaneSize({ "Right", 5 }),
	},
	{
		key = "o",
		mods = mod,
		action = act.ActivatePaneDirection("Next"),
	},
	{
		key = "O",
		mods = mod .. "|SHIFT",
		action = act.PaneSelect({}),
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
		mods = rotmod,
		action = wezterm.action.RotatePanes("Clockwise"),
	},
	{
		key = "O",
		mods = rotmod,
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
