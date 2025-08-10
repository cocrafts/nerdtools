# Common key modifier combinations for Karabiner configuration

# Single modifiers
let
  none* = newSeq[string]()
  cmd* = @["left_command"]
  shift* = @["left_shift"]
  opt* = @["left_option"]
  ctrl* = @["left_control"]
  fn* = @["fn"]

# Double modifier combinations
let
  cmdShift* = @["left_command", "left_shift"]
  cmdOpt* = @["left_command", "left_option"]
  cmdCtrl* = @["left_command", "left_control"]
  shiftOpt* = @["left_shift", "left_option"]
  shiftCtrl* = @["left_shift", "left_control"]
  optShift* = @["left_option", "left_shift"]
  optCtrl* = @["left_option", "left_control"]
  ctrlShift* = @["left_control", "left_shift"]

# Triple modifier combinations
let
  cmdShiftOpt* = @["left_command", "left_shift", "left_option"]
  cmdShiftCtrl* = @["left_command", "left_shift", "left_control"]
  shiftCmdOpt* = @["left_shift", "left_command", "left_option"]

# Special combinations
let
  shiftCmd* = @["left_shift", "left_command"]  # For line selection