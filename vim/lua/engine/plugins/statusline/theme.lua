local M = {}

local colors = {
  blue = "#51afef",
  darkblue = "#081633",
  green = "#98be65",
  purple = "#c678dd",
  red = "#ec5f67",
  yellow = "#ECBE7B",
  orange = "#FF8800",
  fg = "#bbc2cf",
  bg = "#2c3039",
  bg1 = "#21252e",
  bg2 = "#1b1f27",
  gray1 = "#5c6370",
  gray2 = "#2c323d",
  gray3 = "#3e4452",
}

M.config = {
  normal = {
    a = { fg = colors.fg, bg = colors.blue, },
    b = { fg = colors.blue, bg = colors.bg1, },
    c = { fg = colors.fg, bg = colors.bg },
  },
  insert = {
    a = { fg = colors.fg, bg = colors.green, },
    b = { fg = colors.green, bg = colors.bg1, },
  },
  visual = {
    a = { fg = colors.fg, bg = colors.purple, },
    b = { fg = colors.purple, bg = colors.bg1, },
  },
  command = {
    a = { fg = colors.fg, bg = colors.yellow, gui = "bold", },
    b = { fg = colors.yellow, bg = colors.bg1, },
  },
  replace = {
    a = { fg = colors.fg, bg = colors.red, gui = "bold", },
  },
  inactive = {
    a = { fg = colors.bg2, bg = colors.blue, gui = "bold", },
    b = { bg = colors.bg },
    c = { bg = colors.bg },
  },
}

M.colors = colors
return M
