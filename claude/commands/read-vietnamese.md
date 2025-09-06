---
allowed-tools:
  - Read(*)
  - Bash(say -v "Linh":*)
  - Bash(echo:*)
  - Bash(bc:*)
description: Read a document in Vietnamese with adjustable speed (default 1.5x) using Claude translation
---

## Task

Translate the provided file to Vietnamese and read it aloud using text-to-speech.

## Usage

- `/read-vietnamese <file_path>` (uses default 1.5x speed)
- `/read-vietnamese <file_path> <speed>` (custom speed, e.g., 1, 1.5, 2)

## Steps

1. Read the file at: $1
2. Translate the entire content to Vietnamese (keep it natural and fluent)
3. Use the following bash command to speak the translation:

```bash
SPEED="${2:-1.5}"  # Default to 1.5 if not provided
WPM=$(echo "200 * $SPEED" | bc | cut -d. -f1)

echo "[Translated Vietnamese text here]" | say -v "Linh" -r "$WPM" &

echo "🔊 Speaking in Vietnamese at ${SPEED}x speed ($WPM wpm)"
echo "💡 To stop: Use /stop-reading or run: killall say"
```

## Important

- Translate the ENTIRE file content to natural, fluent Vietnamese
- Keep the translation conversational and easy to understand
- Preserve the meaning and tone of the original text
- Use the Linh voice for authentic Vietnamese pronunciation