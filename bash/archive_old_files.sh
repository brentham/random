#!/bin/bash

# Configuration
SLIDES_SRC="/mnt/datastore/test-data/images/slides"
SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"
MARKUP_SRC="/mnt/datastore/test-data/images/markup"
MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# Logging setup
LOG_DIR="/var/log/archive_script"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function (records moves with timestamps)
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Move OLD FOLDERS (depth=1 to avoid nested subfolders)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mmin +1 | while read -r folder; do
  dest="$SLIDES_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mmin +1 | while read -r folder; do
  dest="$MARKUP_ARCHIVE/$(basename "$folder")"
  mv -v "$folder" "$dest"
  log_action "MOVED FOLDER: $folder → $dest"
done

# Move LOOSE FILES (excluding files in subfolders)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mmin +1 | while read -r file; do
  dest="$SLIDES_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file")"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mmin +1 | while read -r file; do
  dest="$MARKUP_ARCHIVE/"
  mv -v "$file" "$dest"
  log_action "MOVED FILE: $file → $dest$(basename "$file")"
done

log_action "Archive job completed."