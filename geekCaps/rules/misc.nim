import std/json
import ../utils
import ../keys

proc generateMiscRules*(): JsonNode =
  # All bash shortcuts use the same pattern
  let ctrlPattern = @[(none, ctrl)]

  let keyMaps = [
    # Terminal bindings
    ("z", "z", ctrlPattern),  # SIGTSTP
    ("x", "x", ctrlPattern),  # IDE Run
    ("c", "c", ctrlPattern),  # SIGINT
    ("v", "v", ctrlPattern),  # Vim Prefix
    ("b", "b", ctrlPattern),  # Tmux Prefix
    ("d", "d", ctrlPattern),   # EOF
    # Deletion
    ("n", "delete_or_backspace", @[(none, opt), (shift, opt), (cmd, opt)]),
    ("m", "delete_or_backspace", @[(none, none), (shift, none), (cmd, none), (opt, none)]),
  ]

  result = buildRuleGroup("Geek Misc", @keyMaps)
