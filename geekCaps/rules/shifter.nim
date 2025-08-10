import std/json
import ../utils
import ../keys

proc generateShifterRules*(): JsonNode =
  # All shifter keys use the same pattern
  let shiftPattern = @[(none, shift)]

  let keyMaps = [
    ("1", "1", shiftPattern),  # !
    ("2", "2", shiftPattern),  # @
    ("3", "3", shiftPattern),  # #
    ("4", "4", shiftPattern),  # $
    ("5", "5", shiftPattern),  # %
    ("6", "6", shiftPattern),  # ^
    ("7", "7", shiftPattern),  # &
    ("8", "8", shiftPattern),  # *
    ("9", "9", shiftPattern),  # (
    ("0", "0", shiftPattern),  # )
    ("hyphen", "hyphen", shiftPattern),  # _
    ("equal_sign", "equal_sign", shiftPattern)  # +
  ]

  result = buildRuleGroup("Geek Shifter", @keyMaps)
