---
allowed-tools:
  - Bash(cat:*)
  - Bash(ollama run gemma3:*)
  - Bash(say -v "Linh":*)
  - Bash(echo:*)
  - Bash(test:*)
  - Bash([[:*)
  - Bash(if:*)
  - Bash(exit:*)
  - Bash(awk:*)
  - Bash(grep:*)
description: Read a document in Vietnamese with adjustable speed (default 1.5x)
---

## Task

Read and translate the file to Vietnamese with optional speed control.

Usage: `/read-vietnamese <file_path> [speed]`
- Default speed: 1.5x if not specified
- Examples: 
  - `/read-vietnamese file.md` (uses default 1.5x)
  - `/read-vietnamese file.md 2` (uses 2x speed)
  - `/read-vietnamese file.md 1` (uses normal speed)
  - `/read-vietnamese file.md 0.5` (uses half speed)

## Execute this exact bash command:

```bash
# Use positional arguments
FILE_PATH="$1"
SPEED="${2:-1.5}"  # Default to 1.5 if not provided

# Check if file path provided
if [ -z "$FILE_PATH" ]; then
    echo "❌ Error: No file path provided"
    echo "Usage: /read-vietnamese <file_path> [speed=X]"
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
echo "⚡ Speed: ${SPEED}x ($WPM wpm)"
echo "🔄 Translating to Vietnamese with gemma3:4b model..."
echo "   This may take 30-60 seconds depending on document length"
echo ""

# Create a temporary file to store translation (needed for deduplication)
TEMP_FILE="/tmp/viet_translation_$$.txt"

# Translate with ollama - add length limit to prevent model degradation
# Split into chunks if file is very large
FILE_SIZE=$(wc -l < "$FILE_PATH")

if [ "$FILE_SIZE" -gt 200 ]; then
    echo "📄 Large file detected. Processing in chunks..."
    # Process in 150-line chunks for better translation quality
    split -l 150 "$FILE_PATH" /tmp/chunk_
    
    for chunk in /tmp/chunk_*; do
        cat "$chunk" | ollama run gemma3:4b "Dịch sang tiếng Việt. Vietnamese only:" 2>/dev/null >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"  # Add separator between chunks
    done
    rm -f /tmp/chunk_*
else
    # Process entire file for smaller documents
    cat "$FILE_PATH" | ollama run gemma3:4b "Dịch sang tiếng Việt. Vietnamese only:" 2>/dev/null > "$TEMP_FILE"
fi

# Clean up terminal escape codes that ollama might output
sed -i '' 's/\[?25[lh]//g' "$TEMP_FILE" 2>/dev/null || sed -i 's/\[?25[lh]//g' "$TEMP_FILE"

# Enhanced filtering to prevent repetition and remove English text
# 1. Remove duplicate lines
# 2. Remove lines that are clearly English (contain common English words)
# 3. Limit any line to max 3 repetitions
awk '
    !seen[$0]++ || ++count[$0] <= 3 {
        # Skip lines that look like untranslated English
        if ($0 !~ /^[A-Z][a-z]+ [A-Z][a-z]+:/ && 
            $0 !~ /\b(The|This|That|With|From|Your|Reality)\b/ &&
            $0 !~ /^[0-9]+\. [A-Z]/) {
            print
        }
    }
' "$TEMP_FILE" | say -v "Linh" -r "$WPM" &

# Clean up temp file after a delay
(sleep 5 && rm -f "$TEMP_FILE") &

# Capture the TTS process ID
TTS_PID=$!

echo "🔊 Speaking in Vietnamese at 1.5x speed (300 wpm)"
echo "🎧 TTS Process ID: $TTS_PID"
echo "💡 To stop: Use /stop-reading or run: killall say"
echo "✅ Translation and speech started in background"
```

## Key requirements:
- Read THE ENTIRE FILE without truncation
- Use gemma3:4b model for translation
- Vietnamese voice "Linh" at 300 wpm (1.5x speed)
- Run in background (&) so it can be stopped
- No temporary files - everything piped in memory
- Show clear progress messages
