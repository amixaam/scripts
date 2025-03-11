#!/bin/bash
# sub-extract: Extract subtitles from all .mkv files in a given directory.
#
# Usage:
#   ./sub-extract [-s <subtitle track>] [-l] /path/to/directory
#
# Options:
#   -s <subtitle track>   Extract only the specified subtitle track number.
#   -l                    List subtitle track details (ID, language, name, and codec) only.
#
# This script uses mkvmerge and mkvextract (from MKVToolNix) to list or extract subtitle tracks.
# In listing mode, it outputs detailed subtitle track information (ID, language, name, codec).
# In extraction mode, subtitles are renamed based on the subtitle track name and proper extension
# based on the codec (e.g., .ass for ASS subtitles, .srt for SubRip).
#
# Ensure MKVToolNix and jq are installed and that mkvmerge, mkvextract, and jq are in your PATH.

usage() {
  echo "Usage: $0 [-s <subtitle track>] [-l] /path/to/directory"
  exit 1
}

determine_extension() {
  codec="$1"
  if echo "$codec" | grep -qi "ASS\|SSA\|SubStationAlpha"; then
    echo ".ass"
  elif echo "$codec" | grep -qi "SubRip"; then
    echo ".srt"
  elif echo "$codec" | grep -qi "HDMV PGS\|S_HDMV/PGS"; then
    echo ".sup"
  else
    echo ".srt" # Default fallback
  fi
}

# Initialize variables.
subtitle_track=""
list_tracks=false

# Parse options.
while getopts ":s:l" opt; do
  case ${opt} in
  s)
    subtitle_track=${OPTARG}
    ;;
  l)
    list_tracks=true
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    usage
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

# Check if directory argument is provided, otherwise use current directory
if [ $# -eq 0 ]; then
  directory="."
else
  directory="$1"
fi

# Check if the provided path is a directory.
if [ ! -d "$directory" ]; then
  echo "Error: Directory '$directory' does not exist." >&2
  exit 1
fi

# Ensure jq is installed.
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required for processing subtitle details." >&2
  exit 1
fi

# Process each .mkv file in the given directory.
shopt -s nullglob
for file in "$directory"/*.mkv; do
  basefile=$(basename "$file")
  if [ "$list_tracks" = true ]; then
    echo "Subtitle track details in $basefile:"
    mkvmerge -J "$file" | jq -r '.tracks[] | select(.type=="subtitles") | "ID: \(.id)  Language: \(.properties.language)  Name: \(.properties.track_name)  Codec: \(.codec)"'
    echo "--------------------------------"
  else
    echo "Processing file: $basefile"
    json=$(mkvmerge -J "$file")
    if [ -n "$subtitle_track" ]; then
      # Find the subtitle track with the given id.
      track_json=$(echo "$json" | jq -c ".tracks[] | select(.type==\"subtitles\" and .id==$subtitle_track)")
      if [ -z "$track_json" ]; then
        echo "Subtitle track $subtitle_track not found in $basefile" >&2
        continue
      fi
      track_name=$(echo "$track_json" | jq -r '.properties.track_name')
      codec=$(echo "$track_json" | jq -r '.codec')
      ext=$(determine_extension "$codec")
      if [ -z "$track_name" ] || [ "$track_name" = "null" ]; then
        track_name="$subtitle_track"
      fi
      sanitized_track_name=$(echo "$track_name" | sed -E 's/[^A-Za-z0-9._-]+/_/g')
      output_file="${file%.*}.${sanitized_track_name}${ext}"
      echo "Extracting subtitle track $subtitle_track ($track_name, Codec: $codec) from $basefile to $(basename "$output_file")"
      mkvextract tracks "$file" ${subtitle_track}:"$output_file"
    else
      echo "Identifying subtitle tracks in $basefile..."
      echo "$json" | jq -c '.tracks[] | select(.type=="subtitles")' | while IFS= read -r track; do
        id=$(echo "$track" | jq -r '.id')
        track_name=$(echo "$track" | jq -r '.properties.track_name')
        codec=$(echo "$track" | jq -r '.codec')
        ext=$(determine_extension "$codec")
        if [ -z "$track_name" ] || [ "$track_name" = "null" ]; then
          track_name="$id"
        fi
        sanitized_track_name=$(echo "$track_name" | sed -E 's/[^A-Za-z0-9._-]+/_/g')
        output_file="${file%.*}_${sanitized_track_name}${ext}"
        echo "Extracting subtitle track $id ($track_name, Codec: $codec) to $(basename "$output_file")"
        mkvextract tracks "$file" ${id}:"$output_file"
      done
    fi
    echo "--------------------------------"
  fi
done

echo "Done."
