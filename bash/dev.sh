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
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Move OLD FOLDERS (depth=1 to avoid nested subfolders)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  dest="$SLIDES_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest"
done

# Move Markup OLD FOLDERS (depth=1 to avoid nested subfolders)
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  dest="$MARKUP_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest"
done

# Move Controls OLD FOLDERS (depth=1 to avoid nested subfolders)
find "$CONTROLS_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  dest="$CONTROLS_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest"
done

# Move LOOSE FILES
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  dest="$SLIDES_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file")"
done

# Move LOOSE FILES
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  dest="$MARKUP_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file")"
done

log_action "Archive job completed."
