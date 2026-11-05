local M = {}

local mac = vim.uv.os_uname().sysname == "Darwin"

M.mod = mac and "C" or "M"
M.other_mod = mac and "M" or "C"

M.lead = function(key)
	return "<" .. M.mod .. "-" .. key .. ">"
end

M.other = function(key)
	return "<" .. M.other_mod .. "-" .. key .. ">"
end

local generic_opts_any = { noremap = true, silent = true }
local generic_opts = {
	x = { silent = true },
}

M.set_keymap = function(mode, key, val, opts)
	opts = opts and opts or (generic_opts[mode] and generic_opts[mode] or generic_opts_any)
	vim.api.nvim_set_keymap(mode, key, val, opts)
end

M.mode_keys = function(mode, keymaps, opts)
	for k, v in pairs(keymaps) do
		M.set_keymap(mode, k, v, opts)
	end
end

M.buf_map = function(bufnr, mode, lhs, rhs, opts)
	vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts or {
		silent = true,
	})
end

return M
