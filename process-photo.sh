#!/bin/bash
#
# process-photo.sh
# Converts a photo to webp, strips metadata, resizes for web.
# Your original file is never touched.
#
# Usage:
#   ./process-photo.sh /path/to/photo.jpg
#   ./process-photo.sh /path/to/photo.jpg my-custom-name
#
# Output goes to tubes/ folder as a .webp file.
# If no custom name is given, the original filename is used.
#

set -e

# ---- CONFIG ----
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/tubes"
MAX_WIDTH=1200
QUALITY=80

# ---- CHECK ARGS ----
if [ -z "$1" ]; then
  echo "Usage: ./process-photo.sh <path-to-image> [output-name]"
  echo "Example: ./process-photo.sh ~/Desktop/my-photo.jpg"
  echo "Example: ./process-photo.sh ~/Desktop/my-photo.jpg plaster-closeup"
  exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  echo "Error: File not found: $INPUT"
  exit 1
fi

# ---- OUTPUT NAME ----
if [ -n "$2" ]; then
  BASENAME="$2"
else
  BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
fi

OUTPUT="$OUTPUT_DIR/${BASENAME}.webp"

# ---- CHECK FOR TOOLS ----
if command -v sips &> /dev/null && command -v cwebp &> /dev/null; then
  # macOS with cwebp installed (brew install webp)
  echo "Processing: $(basename "$INPUT")"

  # Create a temp copy to resize (never touch the original)
  TEMP=$(mktemp /tmp/photo-process-XXXXXX)
  cp "$INPUT" "$TEMP"

  # Resize temp copy (only shrinks, never enlarges)
  CURRENT_WIDTH=$(sips -g pixelWidth "$TEMP" | tail -1 | awk '{print $2}')
  if [ "$CURRENT_WIDTH" -gt "$MAX_WIDTH" ]; then
    sips --resampleWidth "$MAX_WIDTH" "$TEMP" --out "$TEMP" > /dev/null 2>&1
  fi

  # Convert to webp, strip metadata
  cwebp -q "$QUALITY" -metadata none "$TEMP" -o "$OUTPUT" > /dev/null 2>&1

  rm -f "$TEMP"

elif command -v convert &> /dev/null; then
  # ImageMagick available
  echo "Processing: $(basename "$INPUT")"

  convert "$INPUT" -resize "${MAX_WIDTH}x>" -strip -quality "$QUALITY" "$OUTPUT"

elif command -v sips &> /dev/null; then
  # macOS without cwebp — use sips + fallback to JPEG
  echo "Warning: cwebp not found. Install with: brew install webp"
  echo "Falling back to sips (output will be JPEG, not WebP)"

  OUTPUT="$OUTPUT_DIR/${BASENAME}.jpg"
  TEMP=$(mktemp /tmp/photo-process-XXXXXX)
  cp "$INPUT" "$TEMP"

  CURRENT_WIDTH=$(sips -g pixelWidth "$TEMP" | tail -1 | awk '{print $2}')
  if [ "$CURRENT_WIDTH" -gt "$MAX_WIDTH" ]; then
    sips --resampleWidth "$MAX_WIDTH" "$TEMP" --out "$TEMP" > /dev/null 2>&1
  fi

  sips -s format jpeg -s formatOptions "$QUALITY" "$TEMP" --out "$OUTPUT" > /dev/null 2>&1

  rm -f "$TEMP"

  echo "Output: $OUTPUT"
  echo "Note: Install cwebp for proper WebP output: brew install webp"
  exit 0

else
  echo "Error: No image tools found."
  echo "Install one of:"
  echo "  brew install webp       (for cwebp)"
  echo "  brew install imagemagick (for convert)"
  exit 1
fi

# ---- DONE ----
chmod 644 "$OUTPUT"
SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
echo "Done: $OUTPUT ($SIZE)"
