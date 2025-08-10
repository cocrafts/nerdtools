import std/json
import ../types
import ../utils

proc generateCapsRule*(config: GeekCapsConfig): JsonNode =
  let capsFrom = %*{
    "key_code": config.capsKey,
    "modifiers": {
      "optional": ["any"]
    }
  }

  let capsTo = %*[{
    "key_code": "right_shift",
    "modifiers": essentialModifiers
  }]

  let capsManipulator = %*{
    "from": capsFrom,
    "to": capsTo,
    "to_if_alone": [{"key_code": "escape"}],
    "type": "basic"
  }

  # Right Command to Right Control mapping
  let rightCmdToCtrl = %*{
    "from": %*{
      "key_code": "right_command",
      "modifiers": {
        "optional": ["any"]
      }
    },
    "to": %*[{
      "key_code": "right_control"
    }],
    "type": "basic"
  }

  result = generateGroup("CapsLock to GeekCaps", @[capsManipulator, rightCmdToCtrl])
