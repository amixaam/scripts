#!/bin/bash
# sub-extract: Extract subtitles from all .mkv files in a given directory.
#
# Usage:
#   ./sub-extract [-s <subtitle track>] [-l] /path/to/directory
#
# Options:
#   -s <subtitle track>   Extract only the specified subtitle track number.
#   -l                    List subtitle track IDs only (without full path echoes).
#
# This script uses mkvmerge and mkvextract (from MKVToolNix) to list or extract subtitle tracks.
# When listing, it filters mkvmerge's output to show only subtitle track IDs.
#
# Ensure MKVToolNix is installed and that mkvmerge and mkvextract are in your PATH.

usage() {
  echo "Usage: $0 [-s <subtitle track>] [-l] /path/to/directory"
  exit 1
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

# Ensure the directory argument is provided.
if [ $# -eq 0 ]; then
  usage
fi

directory="$1"

# Check if the provided path is a directory.
if [ ! -d "$directory" ]; then
  echo "Error: Directory '$directory' does not exist." >&2
  exit 1
fi

# Process each .mkv file in the given directory.
shopt -s nullglob
for file in "$directory"/*.mkv; do
  basefile=$(basename "$file")
  if [ "$list_tracks" = true ]; then
    echo "Subtitle track IDs in $basefile:"
    # List only lines with "subtitles" and extract the track ID.
    mkvmerge -i "$file" | grep -i "subtitles" | while IFS= read -r line; do
      track_id=$(echo "$line" | awk '{print $3}' | sed 's/://')
      echo "Subtitle track ID: $track_id"
    done
    echo "--------------------------------"
  else
    echo "Processing file: $basefile"
    if [ -n "$subtitle_track" ]; then
      output_file="${file%.*}.subtitle_${subtitle_track}.srt"
      base_output_file=$(basename "$output_file")
      echo "Extracting subtitle track $subtitle_track from $basefile to $base_output_file"
      mkvextract tracks "$file" ${subtitle_track}:"$output_file"
    else
      echo "Identifying subtitle tracks in $basefile..."
      track_info=$(mkvmerge -i "$file")
      while IFS= read -r line; do
        if echo "$line" | grep -qi "subtitles"; then
          track_id=$(echo "$line" | awk '{print $3}' | sed 's/://')
          output_file="${file%.*}_subtitle_${track_id}.srt"
          base_output_file=$(basename "$output_file")
          echo "Extracting subtitle track $track_id to $base_output_file"
          mkvextract tracks "$file" ${track_id}:"$output_file"
        fi
      done <<<"$track_info"
    fi
  fi
done

echo "Done."
