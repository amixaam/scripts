#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Queue Video Download
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📺
# @raycast.packageName amixaam/yt-dlp-raycast

# Documentation:
# @raycast.description Drop in a link from your clipboard onto the download queue! Requires yt-dlp to be installed (brew install yt-dlp).
# @raycast.author amixaam
# @raycast.authorURL https://raycast.com/amixaam

# Configuration:
DOWNLOADS_DIR="$HOME/Downloads/yt-dlp"
OUTPUT_FILE="%(title)s.%(ext)s"

# Log file
OUTPUT_LOG=true
LOG_FILE="$HOME/Downloads/yt-dlp/download.log"

# Get the clipboard content
URL=$(pbpaste)

# Validate if the clipboard content is a URL
if [[ ! $URL =~ ^https?:// ]]; then
    echo "Clipboard content is not a valid URL" | tee -a "$LOG_FILE"
    exit 1
fi

# Create Downloads directory if it doesn't exist
mkdir -p "$DOWNLOADS_DIR"

if [ "$OUTPUT_LOG" = true ]; then
    # Ensure log file exists
    touch "$LOG_FILE"
    # Download the video using yt-dlp in the background for queuing and log the output
    yt-dlp --no-progress -o "$DOWNLOADS_DIR/$OUTPUT_FILE" "$URL" >> "$LOG_FILE" 2>&1 &
else
    # Download the video using yt-dlp in the background for queuing without logging
    yt-dlp --no-progress -o "$DOWNLOADS_DIR/$OUTPUT_FILE" "$URL" &
fi

echo "Queued download for: $URL" | tee -a "$LOG_FILE"
