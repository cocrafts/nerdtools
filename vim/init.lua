require("engine"):init()

vim.api.nvim_exec(
  [[
  augroup Packer
    autocmd!
    autocmd BufWritePost *.lua PackerCompile
  augroup end
]],
  false
)

