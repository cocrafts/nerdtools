import std/json
import ../utils
import ../keys

proc generateWindowControlRules*(): JsonNode =
  let keyMaps = [
    ("tab", "tab", @[(none, cmd), (cmd, cmdShift)]),
    ("q", "grave_accent_and_tilde", @[(none, cmd)]), # Switch between same application
    ("q", "escape", @[(cmd, cmdShiftOpt)]),
    ("a", "f11", @[(none, none)]),
    ("a", "f4", @[(cmd, fn)]),
  ]

  result = buildRuleGroup("Geek Window Control", @keyMaps) 
