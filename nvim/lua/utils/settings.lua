local opts = {
	timeout = true,
	timeoutlen = 0, -- time to wait for mapped sequence to complete
}

for k, v in ipairs(opts) do
	vim.opt[k] = v
end

return opts
