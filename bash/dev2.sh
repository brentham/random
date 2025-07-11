#!/bin/bash

# Configuration
SLIDES_SRC="./Images/Slides"
SLIDES_ARCHIVE="./Images/Archive"
CONTROLS_SRC="./Images/Slides/Controls"
CONTROLS_ARCHIVE="./Images/Archive/Controls"
MARKUP_SRC="./Images/Slides/Markup"
MARKUP_ARCHIVE="./Images/Archive/Markup"
DURATION=90

# Logging setup
LOG_DIR="/mnt/tank/scripts/logs/slides-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Move OLD FOLDERS based on last access time
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -atime +$DURATION | while read -r folder; do
  dest="$SLIDES_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest (Last accessed: $(stat -f %Sa "$folder"))"
done

# Move Markup OLD FOLDERS based on last access time
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -atime +$DURATION | while read -r folder; do
  dest="$MARKUP_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest (Last accessed: $(stat -f %Sa "$folder"))"
done

# Move Controls OLD FOLDERS based on last access time
find "$CONTROLS_SRC" -mindepth 1 -maxdepth 1 -type d -atime +$DURATION | while read -r folder; do
  dest="$CONTROLS_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest (Last accessed: $(stat -f %Sa "$folder"))"
done

# Move LOOSE FILES based on last access time
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -atime +$DURATION | while read -r file; do
  dest="$SLIDES_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file") (Last accessed: $(stat -f %Sa "$file"))"
done

# Move Markup LOOSE FILES based on last access time
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -atime +$DURATION | while read -r file; do
  dest="$MARKUP_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file") (Last accessed: $(stat -f %Sa "$file"))"
done

log_action "Archive job completed."