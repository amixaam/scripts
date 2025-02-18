#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Queue Video Download
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📺
# @raycast.packageName amixaam/yt-dlp-raycast

# Documentation:
# @raycast.description Drop in a link from your clipboard onto the download queue! Requires yt-dlp and coreutils to be installed (brew install yt-dlp coreutils).
# @raycast.author amixaam
# @raycast.authorURL https://raycast.com/amixaam

# Configuration:
DOWNLOADS_DIR="$HOME/Downloads/yt-dlp/downloads"
CONFIG_DIR="$HOME/Downloads/yt-dlp/config"
OUTPUT_FILE="%(title)s.%(ext)s"
SEMAPHORE_LIMIT=2  # Maximum number of concurrent downloads
TIMEOUT_SECONDS=7200  # 2 hours timeout per download (in seconds)

# Config and log files
SEMAPHORE_FILE="$CONFIG_DIR/semaphore.count"
QUEUE_FILE="$CONFIG_DIR/queue.txt"
LOCK_FILE="$CONFIG_DIR/lock.txt"
LOG_FILE="$CONFIG_DIR/yt-dlp.log"
HISTORY_LOG="$CONFIG_DIR/history.log"
SEMAPHORE_LOCK="$CONFIG_DIR/semaphore.lock"

# Function to initialize and validate the script
initialize_validate() {
    # Check if yt-dlp is installed
    if ! command -v yt-dlp &> /dev/null; then
        echo "Install yt-dlp with 'brew install yt-dlp'."
        exit 1
    fi

    # Create Downloads and Config directories if they don't exist
    mkdir -p "$DOWNLOADS_DIR" || { echo "Failed to create downloads directory" | tee -a "$LOG_FILE"; exit 1; }
    mkdir -p "$CONFIG_DIR" || { echo "Failed to create config directory" | tee -a "$LOG_FILE"; exit 1; }

    # Initialize files
    touch "$QUEUE_FILE" "$LOCK_FILE" "$HISTORY_LOG" || { echo "Failed to initialize files" | tee -a "$LOG_FILE"; exit 1; }
    [[ -f "$SEMAPHORE_FILE" ]] || echo 0 > "$SEMAPHORE_FILE"

    # Get the clipboard content and validate if it's an URL
    URL=$(pbpaste)
    if [[ ! $URL =~ ^https?:// ]]; then
        echo "Clipboard content is not a valid URL" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Check if the video is already downloaded OR in the queue
    if grep -qFx "$URL" "$HISTORY_LOG"; then
        echo "Video has already been downloaded."
        exit 1
    fi
    if grep -qFx "$URL" "$QUEUE_FILE"; then
        echo "Video is already in the queue."
        exit 1
    fi
    if grep -qFx "$URL" "$LOCK_FILE"; then
        echo "Video is already being downloaded."
        exit 1
    fi

    # Add the URL to the queue file
    echo "$URL" >> "$QUEUE_FILE" || { echo "Failed to update queue" | tee -a "$LOG_FILE"; exit 1; }
}

# Function to process the queue
process_queue() {
    while read -r QUEUED_URL; do
        # Skip if the URL is already being downloaded (locked)
        if grep -qFx "$QUEUED_URL" "$LOCK_FILE"; then
            continue
        fi

        # Acquire semaphore with file lock
        (
            flock -x 200
            COUNT=$(cat "$SEMAPHORE_FILE")
            if (( COUNT >= SEMAPHORE_LIMIT )); then
                exit 0  # Semaphore limit reached
            fi
            ((COUNT++))
            echo "$COUNT" > "$SEMAPHORE_FILE"
            exit 1  # Successfully acquired semaphore
        ) 200>"$SEMAPHORE_LOCK"

        if (( $? != 1 )); then
            continue
        fi

        # Add the URL to the lock file
        echo "$QUEUED_URL" >> "$LOCK_FILE" || { echo "Failed to update lock file" | tee -a "$LOG_FILE"; continue; }

        # Remove the URL from the queue file (macOS-compatible sed)
        sed -i '' "/^$(echo "$QUEUED_URL" | sed -e 's/[\/&]/\\&/g')$/d" "$QUEUE_FILE"

        # Download the video in the background with timeout
        (
            echo "[NEW DOWNLOAD] Downloading: $QUEUED_URL" >> "$LOG_FILE" 2>&1
            if ! command -v timeout &> /dev/null; then
                echo "Install coreutils for timeout support (brew install coreutils)" >> "$LOG_FILE"
                yt-dlp --restrict-filenames -o "$DOWNLOADS_DIR/$OUTPUT_FILE" "$QUEUED_URL" >> "$LOG_FILE" 2>&1
            else
                timeout "$TIMEOUT_SECONDS" yt-dlp --restrict-filenames -o "$DOWNLOADS_DIR/$OUTPUT_FILE" "$QUEUED_URL" >> "$LOG_FILE" 2>&1
            fi
            DOWNLOAD_RESULT=$?

            # Update history or log failure
            if (( DOWNLOAD_RESULT == 0 )); then
                echo "$QUEUED_URL" >> "$HISTORY_LOG"
            else
                echo "[ERROR] Download failed: $QUEUED_URL (Code: $DOWNLOAD_RESULT)" >> "$LOG_FILE"
            fi

            # Cleanup: Remove from lock file and release semaphore
            sed -i '' "/^$(echo "$QUEUED_URL" | sed -e 's/[\/&]/\\&/g')$/d" "$LOCK_FILE"
            (
                flock -x 200
                COUNT=$(cat "$SEMAPHORE_FILE")
                ((COUNT--))
                echo "$COUNT" > "$SEMAPHORE_FILE"
            ) 200>"$SEMAPHORE_LOCK"

            # Re-process queue after completion
            "$0" --process-queue &
        ) &
    done < <(grep . "$QUEUE_FILE")  # Ensure empty lines don't cause issues
}

# Handle --process-queue argument
if [[ "$1" == "--process-queue" ]]; then
    process_queue
    exit 0
fi

# Main script
initialize_validate
process_queue
echo "Added to queue!"