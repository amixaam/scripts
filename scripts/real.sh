#!/bin/bash

# real.sh - mimics realpath but also copies result to clipboard
# Usage: real.sh [PATH]

if [ $# -lt 1 ]; then
  echo "Usage: real.sh [PATH]" >&2
  exit 1
fi

# Actual command
real_path=$(realpath "$1")

if [ $? -ne 0 ]; then
  echo "Error: Failed to get real path for '$1'" >&2
  exit 1
fi

echo "$real_path"

# Copy to clipboard based on detected OS
if command -v pbcopy >/dev/null; then
  # macOS
  echo "$real_path" | pbcopy
  echo "Copied to clipboard" >&2
elif command -v xclip >/dev/null; then
  # Linux with xclip
  echo "$real_path" | xclip -selection clipboard
  echo "Copied to clipboard" >&2
elif command -v xsel >/dev/null; then
  # Linux with xsel
  echo "$real_path" | xsel --clipboard
  echo "Copied to clipboard" >&2
elif command -v clip.exe >/dev/null; then
  # Windows (WSL)
  echo "$real_path" | clip.exe
  echo "Copied to clipboard" >&2
else
  echo "Warning: Could not copy to clipboard. No supported clipboard utility found." >&2
  echo "Please install xclip, xsel (Linux), or use macOS/WSL" >&2
  exit 2
fi

exit 0
