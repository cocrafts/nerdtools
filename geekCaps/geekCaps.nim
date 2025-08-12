import std/[json, os, strformat]
import ./types
import ./utils
import ./rules/[caps, navigation, shifter, misc, windowControl, developer]


proc generateKarabinerConfig(): JsonNode =
  var config = GeekCapsConfig(
    capsKey: "caps_lock",
    title: "GeekCaps Enhancement",
    author: "Cloud Le (lehaoson@gmail.com)",
    homepage: "https://github.com/cloudle/geekCaps",
    hostpage: "https://pqrs.org/osx/karabiner/complex_modifications/",
    manual: "https://github.com/cloudle/geekCaps/blob/master/exports/"
  )

  config.importUrl = fmt"karabiner://karabiner/assets/complex_modifications/import?url={gitUrl}"

  let rules = @[
    generateCapsRule(config),
    generateMiscRules(),
    generateNavigationRules(),
    generateShifterRules(),
    generateWindowControlRules(),
    generateDeveloperRules(),
  ]

  result = %*{
    "title": config.title,
    "author": config.author,
    "homepage": config.homepage,
    "hostpage": config.hostpage,
    "manual": config.manual,
    "import_url": config.importUrl,
    "rules": rules
  }

when isMainModule:
  let config = generateKarabinerConfig()
  let jsonStr = config.pretty(indent = 2)

  # Ensure directory exists
  let dir = outputPath.parentDir
  if not dirExists(dir):
    createDir(dir)

  # Write to file
  writeFile(outputPath, jsonStr)
  echo fmt"Karabiner configuration written to: {outputPath}"
  echo "Configuration generated successfully!"
