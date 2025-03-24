local M = {}

M.configureImage = function()
	require("image").setup({
		processor = "magick_cli",
	})

	-- disable conceal for Markdown, force accurate Image rendering
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()
			vim.opt_local.conceallevel = 0
			vim.opt_local.wrap = false
		end,
	})
end

M.configureDiagram = function()
	require("diagram").setup({
		renderer_options = {
			mermaid = {
				background = nil, -- nil | "transparent" | "white" | "#hex"
				theme = nil,  -- nil | "default" | "dark" | "forest" | "neutral"
				scale = 1,    -- nil | 1 (default) | 2  | 3 | ...
				width = nil,  -- nil | 800 | 400 | ...
				height = nil, -- nil | 600 | 300 | ...
			},
			plantuml = {
				charset = nil,
			},
			d2 = {
				theme_id = nil,
				dark_theme_id = nil,
				scale = nil,
				layout = nil,
				sketch = nil,
			},
			gnuplot = {
				size = nil, -- nil | "800,600" | ...
				font = nil, -- nil | "Arial,12" | ...
				theme = "dark", -- nil | "light" | "dark" | custom theme string
			},
		},
	})
end

return M
