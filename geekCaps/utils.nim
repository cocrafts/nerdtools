import std/[json, os, sequtils]

const
  essentialModifiers* = @["right_command", "right_control", "right_option"]
  gitUrl* = "https://raw.githubusercontent.com/cloudle/geekCaps/master/exports/karabiner.json"
  outputPath* = expandTilde("~/.config/karabiner/assets/complex_modifications/capslock.json")


proc generateManipulator*(
  fromKey: string,
  toKey: string,
  fromModifiers: seq[string] = @[],
  toModifiers: seq[string] = @[],
  manipulatorType: string = "basic",
): JsonNode =
  let fromNode = %*{
    "key_code": fromKey,
    "modifiers": {
      "mandatory": concat(@essentialModifiers, @["right_shift"], fromModifiers)
    }
  }

  var toNode = %*{"key_code": toKey}
  if toModifiers.len > 0:
    toNode["modifiers"] = %toModifiers

  result = %*{
    "from": fromNode,
    "to": toNode,
    "type": manipulatorType
  }

proc generateManipulators*(
  fromKey: string, toKey: string,
  variations: seq[(seq[string], seq[string])],
): seq[JsonNode] =
  result = @[]
  for (fromMods, toMods) in variations:
    result.add(generateManipulator(fromKey, toKey, fromMods, toMods))

proc generateGroup*(description: string, manipulators: seq[JsonNode]): JsonNode =
  result = %*{
    "description": description,
    "manipulators": manipulators
  }

proc buildRuleGroup*(description: string, keyMaps: seq[(string, string, seq[(seq[string], seq[string])])]): JsonNode =
  var manipulators: seq[JsonNode] = @[]
  for (fromKey, toKey, variations) in keyMaps:
    manipulators.add generateManipulators(fromKey, toKey, variations)
  result = generateGroup(description, manipulators.concat)
