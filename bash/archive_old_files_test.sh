#!/bin/bash

# Configuration

SLIDES_SRC="./images/slides"
SLIDES_ARCHIVE="./images/archive/slides"
MARKUP_SRC="./images/markup"
MARKUP_ARCHIVE="./images/archive/markup"

# Logging setup
LOG_DIR="./var/log/archive_script"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# # Log function (records moves with timestamps)
# log_action() {
#   echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
# }

# # Move OLD FOLDERS (depth=1 to avoid nested subfolders)
# find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mmin +1 | while read -r folder; do
#   dest="$SLIDES_ARCHIVE/$(basename "$folder")"
#   mv -v "$folder" "$dest"
#   log_action "MOVED FOLDER: $folder → $dest"
# done

# find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mmin +1 | while read -r folder; do
#   dest="$MARKUP_ARCHIVE/$(basename "$folder")"
#   mv -v "$folder" "$dest"
#   log_action "MOVED FOLDER: $folder → $dest"
# done

# # Move LOOSE FILES (excluding files in subfolders)
# find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mmin +1 | while read -r file; do
#   dest="$SLIDES_ARCHIVE/"
#   mv -v "$file" "$dest"
#   log_action "MOVED FILE: $file → $dest$(basename "$file")"
# done

# find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mmin +1 | while read -r file; do
#   dest="$MARKUP_ARCHIVE/"
#   mv -v "$file" "$dest"
#   log_action "MOVED FILE: $file → $dest$(basename "$file")"
# done

# log_action "Archive job completed."




#!/bin/bash

# Configuration
# SLIDES_SRC="/mnt/datastore/test-data/images/slides"
# SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"
# MARKUP_SRC="/mnt/datastore/test-data/images/markup"
# MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# # Logging setup
# LOG_DIR="/var/log/archive_script"
# LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
# mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Safe move function (merges folders, overwrites files)
safe_move() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir/$name"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      # Merge folders (skip existing files, log conflicts)
      rsync -a --ignore-existing "$src/" "$dest/"
      log_action "MERGED FOLDER: $src → $dest (merged contents)"
    else
      # Move new folder
      mv -v "$src" "$dest_dir"
      log_action "MOVED FOLDER: $src → $dest"
    fi
  else
    # Overwrite files
    mv -vf "$src" "$dest_dir"
    log_action "MOVED FILE: $src → $dest_dir/$name"
  fi
}

# Move OLD FOLDERS (depth=1)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$SLIDES_ARCHIVE"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$MARKUP_ARCHIVE"
done

log_action "Archive job completed."