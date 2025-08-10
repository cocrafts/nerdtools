# Package

version       = "0.1.0"
author        = "Your Name"
description   = "GeekCaps Karabiner configuration generator in Nim"
license       = "MIT"
srcDir        = "."
bin           = @["geekCaps"]

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task configure, "Build and reload Karabiner config":
  exec "nim c geekCaps.nim"
  exec "./geekCaps"
