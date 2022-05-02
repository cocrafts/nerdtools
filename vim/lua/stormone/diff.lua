local C = require("stormone.colors")

return {
  SignAdd = { fg = C.green },
  SignChange = { fg = C.blue },
  SignDelete = { fg = C.sign_delete },
  GitSignsAdd = { fg = C.green },
  GitSignsChange = { fg = C.blue },
  GitSignsDelete = { fg = C.sign_delete },

  DiffViewNormal = { fg = C.gray, bg = C.alt_bg },
  DiffviewStatusAdded = { fg = C.green },
  DiffviewStatusModified = { fg = C.blue },
  DiffviewStatusRenamed = { fg = C.cyan },
  DiffviewStatusDeleted = { fg = C.sign_delete },
  DiffviewFilePanelInsertion = { fg = C.sign_add },
  DiffviewFilePanelDeletion = { fg = C.sign_delete },
  DiffviewVertSplit = { bg = C.bg },
  DiffAdd = { fg = C.none, bg = C.diff_add },
  DiffDelete = { fg = C.none, bg = C.diff_delete },
  DiffChange = { fg = C.none, bg = C.diff_change, style = "bold" },
  DiffText = { fg = C.none, bg = C.diff_text },
  DiffAdded = { fg = C.green },
  DiffRemoved = { fg = C.red },
  DiffFile = { fg = C.cyan },
  DiffFileId = { fg = C.blue, style = "bold,reverse" },
  DiffNewFile = { fg = C.green },
  DiffOldFile = { fg = C.red },
  DiffIndexLine = { fg = C.gray },
}
