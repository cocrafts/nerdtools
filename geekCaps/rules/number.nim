import std/json
import ../utils
import ../keys

proc generateNumberRules*(): JsonNode =
  let numberPattern = @[(shift, none)]

  let keyMaps = [
    ("semicolon", "0", numberPattern),
    ("h", "0", numberPattern),
    ("j", "1", numberPattern),
    ("k", "2", numberPattern),
    ("l", "3", numberPattern),
    ("u", "4", numberPattern),
    ("i", "5", numberPattern),
    ("o", "6", numberPattern),
    ("7", "7", numberPattern),
    ("8", "8", numberPattern),
    ("9", "9", numberPattern),
  ]

  result = buildRuleGroup("Geek Number", @keyMaps)
