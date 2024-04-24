#!/bin/bash

shopt -s nocaseglob  # Enable case-insensitive globbing for bash
shopt -s nullglob    # This causes globs that get no matches to return empty string rather than the original pattern.

mkdir -p temp
> fl.txt

# Define an array of possible video file extensions
extensions=("mov" "mp4" "3gp" "avi" "mkv" "flv" "wmv" "mpeg" "mpg" "webm")

declare -a videos

# Check for each type and only add if files exist
for ext in "${extensions[@]}"; do
  files=(*.$ext)
  if [ ${#files[@]} -gt 0 ]; then
    videos+=("${files[@]}")
  fi
done

# Check if no videos were found
if [ ${#videos[@]} -eq 0 ]; then
  echo "No video files found. Exiting."
  exit 1
fi

declare -a creation_times
declare -a filenames

# Extract metadata and add to arrays
for f in "${videos[@]}"; do
  creation_time=$(ffprobe -v error -select_streams v:0 -show_entries stream_tags=creation_time -of default=noprint_wrappers=1:nokey=1 "$f")
  creation_times+=("$creation_time")
  filenames+=("$f")
done

# Process and encode files
for f in "${filenames[@]}"; do
  eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=height,width "$f")

  if [ "$streams_stream_0_width" -gt "$streams_stream_0_height" ]; then
    vf="scale=3840:2160:force_original_aspect_ratio=decrease,pad=3840:2160:(ow-iw)/2:(oh-ih)/2,fps=30"
    codec="h264_videotoolbox"
  else
    vf="scale=1080:-1,setsar=1,pad=3840:2160:(3840-iw)/2:(2160-ih)/2:black"
    codec="h264_videotoolbox"
  fi

  # Ensure audio is re-encoded uniformly for all videos
  ffmpeg -i "$f" -vf "$vf" -c:v $codec -b:v 5000k -c:a aac -ar 48000 -b:a 192k "temp/$f"
  echo "file '$(echo "temp/$f" | sed "s/'/'\\\\''/g")'" >> fl.txt  # Properly escape filenames
done

# Concatenate with re-encoding to ensure compatibility
ffmpeg -f concat -safe 0 -i fl.txt -c:v libx264 -crf 23 -preset fast -c:a aac -ar 48000 -b:a 192k output.mp4

# Optional: Remove temp directory
rm -r temp
