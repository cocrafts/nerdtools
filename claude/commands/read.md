---
allowed-tools:
  - Bash(cat:*)
  - Bash(say:*)
  - Bash(echo:*)
  - Bash(test:*)
  - Bash([[:*)
  - Bash(if:*)
  - Bash(exit:*)
description: Read a document aloud in English with adjustable speed (default 1.5x)
---

## Task

Read the file aloud in English using text-to-speech with optional speed control.

Usage: `/read <file_path> [speed] [voice]`
- Default speed: 1.5x if not specified
- Default voice: Daniel (British English)
- Examples: 
  - `/read file.md` (uses default 1.5x, Daniel voice)
  - `/read file.md 2` (uses 2x speed)
  - `/read file.md 1` (uses normal speed)
  - `/read file.md 1.5 Samantha` (1.5x speed with Samantha voice)
  - `/read file.md 2 Karen` (2x speed with Karen voice)

## Execute this exact bash command:

```bash
# Use positional arguments
FILE_PATH="$1"
SPEED="${2:-1.5}"  # Default to 1.5 if not provided
VOICE="${3:-Daniel}"  # Default to Daniel (British) if not provided

# Check if file path provided
if [ -z "$FILE_PATH" ]; then
    echo "❌ Error: No file path provided"
    echo "Usage: /read <file_path> [speed] [voice]"
    exit 1
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "❌ Error: File not found: $FILE_PATH"
    exit 1
fi

# Calculate WPM (200 is normal, so multiply by speed factor)
WPM=$(echo "200 * $SPEED" | bc | cut -d. -f1)

echo "📖 Reading file: $FILE_PATH"
echo "🔊 Voice: $VOICE"
echo "⚡ Speed: ${SPEED}x ($WPM wpm)"
echo ""

# Create a clean temporary file for TTS
TEMP_FILE="/tmp/english_reading_$$.txt"

# Clean the file content for TTS:
# - Remove markdown formatting that might confuse TTS
# - Remove special characters that might cause TTS to stop
# - Ensure proper text flow
cat "$FILE_PATH" | sed 's/[`*_#]//g' | tr -d '\000' > "$TEMP_FILE"

# Read the cleaned file with TTS
say -v "$VOICE" -r "$WPM" -f "$TEMP_FILE" &

# Capture the TTS process ID
TTS_PID=$!

# Clean up temp file after a delay
(sleep 5 && rm -f "$TEMP_FILE") &

echo "🎧 Reading in English... (Process ID: $TTS_PID)"
echo "💡 To stop: Use /stop-reading or run: killall say"
echo "✅ Speech started in background"
```

## Key features:
- Direct reading without translation
- Adjustable speed (default 1.5x)
- Choice of voice (default Daniel)
- Runs in background so it can be stopped
- No temporary files needed