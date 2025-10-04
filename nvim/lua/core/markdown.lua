local M = {}
local colors = require("themes.color")

M.configureRenderMarkdown = function()
	require("render-markdown").setup({
		file_types = { "markdown" },
		bullet = {
			enabled = false,
		},
		checkbox = {
			enabled = true,
			checked = {
				icon = "󰀘 ",
				highlight = "RenderMarkdownChecked",
			},
			unchecked = {
				icon = " ",
				highlight = "RenderMarkdownUnchecked",
			},
		},
	})
end

---@type checkmate.Config
---@diagnostic disable-next-line: missing-fields
local checkmateConfig = {
	ui = {
		picker = "telescope",
	},
	style = {
		CheckmateCheckedMainContent = { fg = colors.comments },
		CheckmateCheckedAdditionalContent = { fg = colors.comments },
		-- CheckmateUncheckedMainContent = { fg = colors.fg },
		CheckmateUncheckedAdditionalContent = { fg = colors.purple },
		CheckmateTodoCountIndicator = { fg = colors.blue },
		CheckmateMeta_Done = { fg = colors.green },
		CheckmateMeta_Started = { fg = colors.comments },
	},
	todo_states = {
		---@diagnostic disable-next-line: missing-fields
		unchecked = {
			marker = "[ ]",
		},
		---@diagnostic disable-next-line: missing-fields
		checked = {
			marker = "[x]",
		},
	},
	metadata = {
		due = {
			key = "<leader>jE",
			get_value = function()
				local t = os.date("*t")
				t.day = t.day + 1
				local tomorrow = os.time(t)
				return os.date("%m/%d/%y", tomorrow)
			end,
		},
		started = {
			key = "<leader>js",
			get_value = function()
				return os.date("%m/%d/%y %H:%M")
			end,
		},
		priority = {
			key = "<leader>jp",
			style = function(context)
				local value = context.value:lower()
				if value == "high" then
					return { fg = colors.red, bold = true }
				elseif value == "medium" then
					return { fg = colors.keywords }
				elseif value == "low" then
					return { fg = colors.types }
				else -- fallback
					return { fg = colors.blue }
				end
			end,
			get_value = function()
				return "medium" -- Default priority
			end,
			choices = function()
				return { "low", "medium", "high" }
			end,
			sort_order = 10,
			jump_to_on_insert = "value",
			select_on_insert = true,
		},
		done = {
			key = "<leader>jj",
			get_value = function()
				return os.date("%m/%d/%y %H:%M")
			end,
			on_add = function(todo_item)
				require("checkmate").set_todo_item(todo_item, "checked")

				local started_meta = todo_item.metadata.by_tag.started

				if started_meta and started_meta.value then
					local started_ts = vim.fn.strptime("%m/%d/%y %H:%M", started_meta.value)
					local done_ts = os.time()
					local elapsed_days = (done_ts - started_ts) / 86400
					require("checkmate").add_metadata("elapsed", string.format("%.1f d", elapsed_days))
				end
			end,
			on_remove = function(todo_item)
				require("checkmate").set_todo_item(todo_item, "unchecked")
				require("checkmate").remove_metadata("elapsed")
			end,
		},
		elapsed = {
			key = "<leader>je",
			get_value = function(context)
				local _, started_value = context.todo.get_metadata("started")
				local _, done_value = context.todo.get_metadata("done")
				if started_value and done_value then
					local started_ts = vim.fn.strptime("%m/%d/%y %H:%M", started_value)
					local done_ts = vim.fn.strptime("%m/%d/%y %H:%M", done_value)
					return string.format("%.1f d", (done_ts - started_ts) / 86400)
				end
				return ""
			end,
		},
	},
	keys = {
		-- Disable defaults (they use <leader>T prefix)
		["<leader>Tt"] = false,
		["<leader>Tc"] = false,
		["<leader>Tu"] = false,
		["<leader>T="] = false,
		["<leader>T-"] = false,
		["<leader>Tn"] = false,
		["<leader>Tr"] = false,
		["<leader>TR"] = false,
		["<leader>Ta"] = false,
		["<leader>Tv"] = false,
		["<leader>T]"] = false,
		["<leader>T["] = false,
		-- Custom keybindings
		-- ["<leader>jj"] = {
		-- 	rhs = "<cmd>Checkmate toggle<CR>",
		-- 	desc = "Toggle todo item",
		-- 	modes = { "n", "v" },
		-- },
		["<leader>jc"] = {
			rhs = "<cmd>Checkmate check<CR>",
			desc = "Set todo item as checked (done)",
			modes = { "n", "v" },
		},
		["<leader>ju"] = {
			rhs = "<cmd>Checkmate uncheck<CR>",
			desc = "Set todo item as unchecked (not done)",
			modes = { "n", "v" },
		},
		["<leader>j="] = {
			rhs = "<cmd>Checkmate cycle_next<CR>",
			desc = "Cycle todo item(s) to the next state",
			modes = { "n", "v" },
		},
		["<leader>j-"] = {
			rhs = "<cmd>Checkmate cycle_previous<CR>",
			desc = "Cycle todo item(s) to the previous state",
			modes = { "n", "v" },
		},
		["<leader>jn"] = {
			rhs = "<cmd>Checkmate create<CR>",
			desc = "Create todo item",
			modes = { "n", "v" },
		},
		["<leader>jr"] = {
			rhs = "<cmd>Checkmate remove<CR>",
			desc = "Remove todo marker (convert to text)",
			modes = { "n", "v" },
		},
		["<leader>jR"] = {
			rhs = "<cmd>Checkmate remove_all_metadata<CR>",
			desc = "Remove all metadata from a todo item",
			modes = { "n", "v" },
		},
		["<leader>ja"] = {
			rhs = "<cmd>Checkmate archive<CR>",
			desc = "Archive checked/completed todo items (move to bottom section)",
			modes = { "n" },
		},
		["<leader>jv"] = {
			rhs = "<cmd>Checkmate metadata select_value<CR>",
			desc = "Update the value of a metadata tag under the cursor",
			modes = { "n" },
		},
		["<leader>j]"] = {
			rhs = "<cmd>Checkmate metadata jump_next<CR>",
			desc = "Move cursor to next metadata tag",
			modes = { "n" },
		},
		["<leader>j["] = {
			rhs = "<cmd>Checkmate metadata jump_previous<CR>",
			desc = "Move cursor to previous metadata tag",
			modes = { "n" },
		},
	},
}

M.configureCheckmate = function()
	require("checkmate").setup(checkmateConfig)
end

return M
