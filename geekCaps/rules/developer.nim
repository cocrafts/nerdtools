import std/json
import ../utils
import ../keys

proc generateDeveloperRules*(): JsonNode =
  let keyMaps = [
    ("escape", "grave_accent_and_tilde", @[(none, none), (cmd, shift)]), # `
    ("delete_or_backspace", "delete_forward", @[(none, none)]),
    ("s", "s", @[(none, cmd)]), # save changes
    # Code/IDE bindings
    ("spacebar", "spacebar", @[(none, ctrl)]), # trigger autocomplete
    ("quote", "equal_sign", @[(none, none), (cmd, shift)]), # =
    ("semicolon", "hyphen", @[(none, none), (cmd, shift)]), # -

    # Pair characters
    ("i", "open_bracket", @[(cmd, none), (shift, shift)]), # [, {
    ("o", "close_bracket", @[(cmd, none), (shift, shift)]), # ], }
    ("i", "9", @[(none, shift)]), # (
    ("o", "0", @[(none, shift)]), # (
    ("comma", "comma", @[(none, shift)]), # <
    ("period", "period", @[(none, shift)]), # >
    # Special characters
    ("open_bracket", "backslash", @[(none, shift)]), # ?
    ("comma", "5", @[(cmd, shift)]), # %
    ("period", "6", @[(cmd, shift)]), # ^
    ("slash", "7", @[(cmd, shift)]), # &
    ("slash", "slash", @[(none, shift)]), # ?
  ]

  result = buildRuleGroup("Geek Developer", @keyMaps)
