#!/bin/bash

# Usage function
usage() {
  echo "Usage: $0 -s SUBTITLE_IDS DIRECTORY_PATH"
  echo "Example: $0 -s 3,4 /path/to/media/"
  echo "This script extracts subtitles from MKV files based on the provided track IDs."
  exit 1
}

# Check for required tools
check_dependencies() {
  if ! command -v mkvinfo &>/dev/null || ! command -v mkvextract &>/dev/null; then
    echo "Error: This script requires MKVToolNix to be installed (mkvinfo and mkvextract)."
    echo "Please install MKVToolNix and try again."
    exit 1
  fi
}

# Determine subtitle format extension based on codec
get_subtitle_extension() {
  local codec="$1"
  case "$codec" in
  *S_TEXT/UTF8* | *S_TEXT/ASCII*) echo "srt" ;;
  *S_TEXT/SSA* | *S_TEXT/ASS*) echo "ass" ;;
  *S_VOBSUB*) echo "sub" ;;
  *S_HDMV/PGS*) echo "sup" ;;
  *S_KATE*) echo "ogg" ;;
  *S_TEXT/USF*) echo "usf" ;;
  *S_TEXT/WEBVTT*) echo "vtt" ;;
  *) echo "txt" ;; # Default fallback
  esac
}

# Get subtitle language and name info
get_subtitle_info() {
  local file="$1"
  local track_id="$2"

  # Get track info for the specified ID
  local track_info=$(mkvinfo "$file" | grep -A 50 "Track number: $track_id" | grep -E "Track type|Language|Name" | head -3)

  # Check if it's a subtitle track
  if echo "$track_info" | grep -q "Track type: subtitles"; then
    local language=$(echo "$track_info" | grep "Language" | sed 's/.*Language: \([^ ]*\).*/\1/' | tr -d '[:space:]' || echo "unknown")
    local name=$(echo "$track_info" | grep "Name" | sed 's/.*Name: \(.*\)/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")

    # Get codec info for the track
    local codec=$(mkvinfo "$file" | grep -A 100 "Track number: $track_id" | grep -m 1 "Codec ID" | sed 's/.*Codec ID: \(.*\)/\1/' | tr -d '[:space:]')

    if [[ -n "$name" ]]; then
      echo "$track_id: $language ($name)"
      return 0
    else
      echo "$track_id: $language"
      return 0
    fi
  else
    echo "$track_id: not found (will skip)"
    return 1
  fi
}

# Get track name for a given track ID
get_track_name() {
  local file="$1"
  local track_id="$2"

  local name=$(mkvinfo "$file" | grep -A 100 "Track number: $track_id" | grep -m 1 "Name:" | sed 's/.*Name: \(.*\)/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [[ -n "$name" ]]; then
    # Replace spaces and special characters with underscores for filename safety
    echo "$name" | tr ' /:\\*?"<>|&' '_'
  else
    echo "track_${track_id}"
  fi
}

# Extract subtitle from MKV file
extract_subtitle() {
  local file="$1"
  local track_id="$2"
  local output_dir=$(dirname "$file")
  local base_filename=$(basename "$file" .mkv)

  # Get track name to use in output filename
  local track_name=$(get_track_name "$file" "$track_id")

  # Get codec info for the track
  local codec=$(mkvinfo "$file" | grep -A 100 "Track number: $track_id" | grep -m 1 "Codec ID" | sed 's/.*Codec ID: \(.*\)/\1/' | tr -d '[:space:]')

  # Get appropriate extension
  local extension=$(get_subtitle_extension "$codec")

  # Create a unique filename with the track ID and name
  local output_filename="${base_filename}.${track_name}.${extension}"

  # Extract the subtitle
  mkvextract tracks "$file" "$track_id:$output_dir/$output_filename" >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "Extracted track $track_id to $output_filename"
  else
    echo "Failed to extract track $track_id"
  fi
}

# Main script
main() {
  check_dependencies

  # Parse command-line arguments
  while getopts ":s:h" opt; do
    case ${opt} in
    s) subtitle_ids=$OPTARG ;;
    h) usage ;;
    \?)
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." 1>&2
      usage
      ;;
    esac
  done

  # Shift to get the directory path
  shift $((OPTIND - 1))

  # Check if directory path is provided
  if [ $# -ne 1 ]; then
    echo "Error: Directory path is required."
    usage
  fi

  dir_path="$1"

  # Check if directory exists
  if [ ! -d "$dir_path" ]; then
    echo "Error: Directory '$dir_path' does not exist."
    exit 1
  fi

  # Use a macOS-compatible approach to get a list of MKV files
  OLDIFS="$IFS"
  IFS=$'\n'
  mkv_files=($(find "$dir_path" -type f -name "*.mkv" | sort))
  IFS="$OLDIFS"
  file_count=${#mkv_files[@]}

  if [ $file_count -eq 0 ]; then
    echo "No MKV files found in $dir_path"
    exit 0
  fi

  echo "Checking $file_count files..."
  echo

  # Convert comma-separated IDs to array
  IFS=',' read -ra id_array <<<"$subtitle_ids"

  # Process each file
  for file in "${mkv_files[@]}"; do
    filename=$(basename "$file")
    echo "$filename:"

    track_found=false

    # Check each subtitle ID
    for id in "${id_array[@]}"; do
      # Get subtitle info
      if get_subtitle_info "$file" "$id"; then
        track_found=true
      fi
    done

    echo
    read -p "continue? [y/n] " choice

    case "$choice" in
    y | Y)
      if [ "$track_found" = true ]; then
        # Extract selected subtitles
        for id in "${id_array[@]}"; do
          # Check if track exists and is a subtitle
          if mkvinfo "$file" | grep -A 50 "Track number: $id" | grep -q "Track type: subtitles"; then
            extract_subtitle "$file" "$id"
          fi
        done
        echo
      fi
      ;;
    *)
      echo "Exiting..."
      exit 0
      ;;
    esac
  done

  echo "All files processed."
}

# Execute main function
main "$@"
