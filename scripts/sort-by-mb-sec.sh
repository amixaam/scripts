#!/bin/bash

# Check if directory path is provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 [-r] <directory_path>"
    exit 1
fi

RECURSIVE=false
SOURCE_DIR=""

# Parse arguments
if [ "$1" = "-r" ]; then
    RECURSIVE=true
    SOURCE_DIR="$2"
else
    SOURCE_DIR="$1"
fi

HIGH_DIR="${SOURCE_DIR}/HIGH"
NORMAL_DIR="${SOURCE_DIR}/NORMAL"
THRESHOLD=0.75  # MB per second threshold

mkdir -p "$HIGH_DIR" "$NORMAL_DIR"

# Function to get video duration in seconds
get_duration() {
    ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

get_size_mb() {
    local size_bytes=$(stat -f %z "$1")
    echo "scale=2; $size_bytes / 1048576" | bc
}

# Process each video file
if [ "$RECURSIVE" = true ]; then
    FIND_CMD="find \"$SOURCE_DIR\" -type f \( -name \"*.mp4\" -o -name \"*.mkv\" -o -name \"*.avi\" -o -name \"*.mov\" \)"
else
    FIND_CMD="find \"$SOURCE_DIR\" -maxdepth 1 -type f \( -name \"*.mp4\" -o -name \"*.mkv\" -o -name \"*.avi\" -o -name \"*.mov\" \)"
fi

eval $FIND_CMD | while read -r video; do
    # Skip files that are already in HIGH or NORMAL directories
    if [[ "$video" == *"/HIGH/"* ]] || [[ "$video" == *"/NORMAL/"* ]]; then
        continue
    fi

    filename=$(basename "$video")
    duration=$(get_duration "$video")
    size_mb=$(get_size_mb "$video")
    
    # Calculate MB per second
    mb_per_sec=$(echo "scale=2; $size_mb / $duration" | bc)
    
    # Determine destination based on MB/sec ratio
    if (( $(echo "$mb_per_sec > $THRESHOLD" | bc -l) )); then
        mv "$video" "$HIGH_DIR/$filename"
        echo "Moving $filename to HIGH (${mb_per_sec}MB/s)"
    else
        mv "$video" "$NORMAL_DIR/$filename"
        echo "Moving $filename to NORMAL (${mb_per_sec}MB/s)"
    fi
done