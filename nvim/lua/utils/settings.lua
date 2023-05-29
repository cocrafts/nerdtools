local globals = {
	mapleader = ' ',
	localmapleader = ' ',
}

local opts = {
	timeout = true,
	timeoutlen = 0, -- time to wait for mapped sequence to complete
}

for k, v in pairs(globals) do
	vim.g[k] = v
end

for k, v in pairs(opts) do
	vim.opt[k] = v
end

return opts
