local opts = { force = true }
local commands = {
	{
		name = "BufferKill",
		fn = function()
			require("core.bufferline").buf_kill("bd")
		end,
	},
}

for _, cmd in pairs(commands) do
	vim.api.nvim_create_user_command(cmd.name, cmd.fn, opts)
end
