import std/json
import ../utils
import ../keys

proc generateNavigationRules*(): JsonNode =
  # Arrow navigation pattern for hjkl
  let arrowPattern = @[
    (none, none),
    (cmd, shift),
    (shift, opt),
    (cmdShift, optShift)
  ]

  let keyMaps = [
    # Arrow navigation
    ("h", "left_arrow", arrowPattern),
    ("j", "down_arrow", arrowPattern),
    ("l", "right_arrow", arrowPattern),
    ("k", "up_arrow", arrowPattern),
    # Line start/end
    ("u", "left_arrow", @[(none, cmd), (cmd, shiftCmd)]),
    ("p", "right_arrow", @[(none, cmd), (cmd, shiftCmd)]),
    # Tab switching
    ("u", "tab", @[(shift, ctrlShift)]),
    ("p", "tab", @[(shift, ctrlShift)])
  ]

  result = buildRuleGroup("Geek Navigation", @keyMaps)
