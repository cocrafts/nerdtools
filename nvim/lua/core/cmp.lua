local M = {}
local config = require("utils.config")
local icons = require("utils.icons")

local has_words_before = function()
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

M.configure = function()
	local cmp = require("cmp")
	local luasnip = require("luasnip")
	local cmp_types = require("cmp.types.cmp")
	local cmp_window = require("cmp.config.window")
	local cmp_mapping = require("cmp.config.mapping")
	local action = require("lsp-zero").cmp_action()
	local ConfirmBehavior = cmp_types.ConfirmBehavior
	local max_width = 0
	local duplicates_default = 0
	local bordered_window = cmp_window.bordered({
		winhighlight = "Normal:CmpNormal,FloatBorder:CmpFloatBorder,CursorLine:CmpCursorLine,Search:None",
		scrollbar = false,
	})
	local duplicates = {
		buffer = 1,
		path = 1,
		nvim_lsp = 0,
		luasnip = 1,
	}
	local source_names = {
		nvim_lsp = "LSP",
		emoji = "Emoji",
		path = "Path",
		calc = "Calc",
		cmp_tabnine = "Tabnine",
		vsnip = "Snippet",
		luasnip = "Snippet",
		buffer = "Buffer",
		tmux = "TMUX",
		copilot = "Copilot",
		treesitter = "TreeSitter",
	}

	local mapping = cmp_mapping.preset.insert({
		-- `Enter` key to confirm completion
		["<CR>"] = cmp.mapping.confirm({ select = false }),
		["<Tab>"] = cmp_mapping(function(fallback)
			if cmp.visible() then
				cmp.confirm()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			elseif has_words_before() then
				cmp.complete()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp_mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
		-- Ctrl+Space to trigger completion menu
		["<C-Space>"] = cmp.mapping.complete(),
		-- Navigate between snippet placeholder
		["<C-f>"] = action.luasnip_jump_forward(),
		["<C-b>"] = action.luasnip_jump_backward(),
	})

	---@class cmp.FormattingConfig
	local formatting = {
		fields = { "kind", "abbr", "menu" },
		max_width = max_width,
		kind_icons = icons.kind,
		source_names = source_names,
		duplicates = duplicates,
		duplicates_default = duplicates_default,
		format = function(entry, vim_item)
			if max_width ~= 0 and #vim_item.abbr > max_width then
				vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 1) .. icons.ui.Ellipsis
			end

			if config.use_icons then
				vim_item.kind = icons.kind[vim_item.kind]

				if entry.source.name == "copilot" then
					vim_item.kind = icons.git.Octoface
					vim_item.kind_hl_group = "CmpItemKindCopilot"
				end

				if entry.source.name == "cmp_tabnine" then
					vim_item.kind = icons.misc.Robot
					vim_item.kind_hl_group = "CmpItemKindTabnine"
				end

				if entry.source.name == "crates" then
					vim_item.kind = icons.misc.Package
					vim_item.kind_hl_group = "CmpItemKindCrate"
				end

				if entry.source.name == "lab.quick_data" then
					vim_item.kind = icons.misc.CircuitBoard
					vim_item.kind_hl_group = "CmpItemKindConstant"
				end

				if entry.source.name == "emoji" then
					vim_item.kind = icons.misc.Smiley
					vim_item.kind_hl_group = "CmpItemKindEmoji"
				end
			end

			vim_item.menu = source_names[entry.source.name]
			---@diagnostic disable-next-line: assign-type-mismatch
			vim_item.dup = duplicates[entry.source.name] or duplicates_default

			return vim_item
		end,
	}

	---@class cmp.ConfigSchema
	local options = {
		enabled = true,
		mapping = mapping,
		formatting = formatting,
		sources = {
			{ name = "crates", priority = 19 },
			{ name = "nvim_lsp", priority = 12 },
			{ name = "path", priority = 10 },
			{ name = "luasnip", priority = 8, keyword_length = 2 },
			{ name = "treesitter", priority = 7 },
			{ name = "buffer", priority = 6, keyword_length = 3 },
		},
		window = {
			completion = bordered_window,
			documentation = bordered_window,
		},
		--- @class cmp.CompletionConfig
		completion = {
			keyword_length = 1,
			completeopt = "menu,menuone,noinsert",
		},
		confirm_opts = {
			behavior = ConfirmBehavior.Replace,
			select = false,
		},
		snippet = {
			expand = function(args)
				luasnip.lsp_expand(args.body)
			end,
		},
		experimental = {
			ghost_text = true,
		},
	}

	local cmdlines = {
		{
			type = ":",
			sources = {
				{ name = "path" },
				{ name = "cmdline" },
			},
		},
		{
			type = { "/", "?" },
			sources = {
				{ name = "buffer" },
			},
		},
	}

	for _, option in ipairs(cmdlines) do
		cmp.setup.cmdline(option.type, {
			mapping = cmp.mapping.preset.cmdline(),
			sources = option.sources,
		})
	end

	cmp.setup(options)
end

return M
