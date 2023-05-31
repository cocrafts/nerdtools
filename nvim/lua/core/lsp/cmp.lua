local M = {}
local icons = require("utils.icons")
local config = require("utils.config")

local max_width = 0
local duplicates_default = 0

local sources = {
	{ name = "path" },
	{ name = "treesitter" },
	{ name = "crates" },
	{ name = "nvim_lsp" },
	{ name = "buffer",    keyword_length = 3 },
	{ name = "luasnip",   keyword_length = 2 },
}

local source_names = {
	nvim_lsp = "(LSP)",
	emoji = "(Emoji)",
	path = "(Path)",
	calc = "(Calc)",
	cmp_tabnine = "(Tabnine)",
	vsnip = "(Snippet)",
	luasnip = "(Snippet)",
	buffer = "(Buffer)",
	tmux = "(TMUX)",
	copilot = "(Copilot)",
	treesitter = "(TreeSitter)",
}

local duplicates = {
	buffer = 1,
	path = 1,
	nvim_lsp = 0,
	luasnip = 1,
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

M.configure = function()
	local cmp = require("cmp")
	local cmp_types = require("cmp.types.cmp")
	local cmp_window = require("cmp.config.window")
	local action = require("lsp-zero").cmp_action()
	local ConfirmBehavior = cmp_types.ConfirmBehavior

	---@diagnostic disable-next-line: redundant-parameter
	cmp.setup({
		sources = sources,
		window = {
			completion = cmp_window.bordered(),
			documentation = cmp_window.bordered(),
		},
		confirm_opts = {
			behavior = ConfirmBehavior.Replace,
			select = false,
		},
		completion = {
			keyword_length = 1,
		},
		formatting = {
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
				vim_item.dup = duplicates[entry.source.name] or duplicates_default
				return vim_item
			end,
		},
		mapping = {
			-- `Enter` key to confirm completion
			['<CR>'] = cmp.mapping.confirm({ select = false }),
			-- Ctrl+Space to trigger completion menu
			['<C-Space>'] = cmp.mapping.complete(),
			-- Navigate between snippet placeholder
			['<C-f>'] = action.luasnip_jump_forward(),
			['<C-b>'] = action.luasnip_jump_backward(),
		},
	})

	for _, option in ipairs(cmdlines) do
		cmp.setup.cmdline(option.type, {
			mapping = cmp.mapping.preset.cmdline(),
			sources = option.sources,
		})
	end
end

return M
