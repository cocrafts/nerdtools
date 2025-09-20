--- Configuration management for Claude integration
--- @module 'core.claude.config'

local M = {}

-- Default configuration
local defaults = {
	-- Core settings
	tracking_file = vim.fn.expand("~/.claude/active-sessions.txt"),
	auto_send_diagnostics = true,
	focus_after_send = true,

	-- Selection tracking
	visual_demotion_delay_ms = 50,
	track_selection = true,
	include_diagnostics = true,
	include_git_status = false,

	-- UI settings
	show_status_in_lualine = true,
	status_timeout_ms = 5000,
	prompt_window = {
		width_percentage = 0.8,
		max_height = 20,
		border = "rounded",
		title = " Claude Prompt (Shift+Enter to send, Esc to cancel) ",
		title_pos = "center",
	},

	-- Diff settings
	diff_opts = {
		auto_close_on_accept = true,
		vertical_split = true,
		highlight_changes = true,
		hide_terminal_in_new_tab = false,
		keep_terminal_focus = false,
	},

	-- WezTerm settings
	wezterm = {
		fallback_to_clipboard = true,
		show_pane_indicators = true,
		auto_detect_panes = true,
	},

	-- Keymaps
	keymaps = {
		send = "<leader>aI",
		send_with_prompt = "<leader>ai",
		focus_claude = "<leader>af",
		accept_diff = "<leader>aa",
		deny_diff = "<leader>ad",
		list_sessions = "<leader>as",
		list_panes = "<leader>ap",
	},

	-- Advanced settings
	debug = false,
	log_level = "info", -- trace, debug, info, warn, error
}

-- Current configuration (merged with defaults)
local config = {}

-- Validate configuration
local function validate_config(user_config)
	if type(user_config) ~= "table" then
		return false, "Configuration must be a table"
	end

	-- Validate specific fields
	if user_config.visual_demotion_delay_ms and type(user_config.visual_demotion_delay_ms) ~= "number" then
		return false, "visual_demotion_delay_ms must be a number"
	end

	if user_config.prompt_window then
		if user_config.prompt_window.width_percentage then
			local wp = user_config.prompt_window.width_percentage
			if type(wp) ~= "number" or wp <= 0 or wp > 1 then
				return false, "prompt_window.width_percentage must be between 0 and 1"
			end
		end
		if user_config.prompt_window.max_height then
			local mh = user_config.prompt_window.max_height
			if type(mh) ~= "number" or mh <= 0 then
				return false, "prompt_window.max_height must be a positive number"
			end
		end
	end

	return true
end

-- Setup configuration
function M.setup(user_config)
	user_config = user_config or {}

	-- Validate user configuration
	local valid, err = validate_config(user_config)
	if not valid then
		vim.notify("Claude config error: " .. err, vim.log.levels.ERROR)
		return false
	end

	-- Deep merge configurations
	config = vim.tbl_deep_extend("force", defaults, user_config)

	-- Expand paths
	config.tracking_file = vim.fn.expand(config.tracking_file)

	return true
end

-- Get configuration value
function M.get(key)
	if key then
		-- Support nested keys with dot notation
		local keys = vim.split(key, ".", { plain = true })
		local value = config
		for _, k in ipairs(keys) do
			if type(value) == "table" then
				value = value[k]
			else
				return nil
			end
		end
		return value
	end
	return config
end

-- Set configuration value
function M.set(key, value)
	if not key then
		return false
	end

	-- Support nested keys with dot notation
	local keys = vim.split(key, ".", { plain = true })
	local target = config
	for i = 1, #keys - 1 do
		local k = keys[i]
		if type(target[k]) ~= "table" then
			target[k] = {}
		end
		target = target[k]
	end
	target[keys[#keys]] = value
	return true
end

-- Get all configuration
function M.get_all()
	return vim.deepcopy(config)
end

-- Reset to defaults
function M.reset()
	config = vim.deepcopy(defaults)
end

-- Check if debug mode is enabled
function M.is_debug()
	return config.debug == true
end

-- Get log level
function M.get_log_level()
	return config.log_level or "info"
end

-- Check if a feature is enabled
function M.is_enabled(feature)
	if feature == "diagnostics" then
		return config.auto_send_diagnostics
	elseif feature == "selection_tracking" then
		return config.track_selection
	elseif feature == "lualine" then
		return config.show_status_in_lualine
	elseif feature == "git" then
		return config.include_git_status
	end
	return false
end

return M