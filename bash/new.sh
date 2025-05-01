#!/bin/sh

# Configuration
SLIDES_SRC="/mnt/datastore/test-data/images/slides"
SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"
MARKUP_SRC="/mnt/datastore/test-data/images/markup"
MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# Logging setup
LOG_DIR="/var/log/archive_script"
DATE_STR=$(date +"%Y-%m-%d")
LOG_FILE="$LOG_DIR/archive_script-$DATE_STR.log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function
log_action() {
  echo "[$(date +"%Y-%m-%d_%H:%M:%S")] $1" >> "$LOG_FILE"
}

# Safe move/merge function with source cleanup
safe_move() {
  src="$1"
  dest_dir="$2"
  name=$(basename "$src")
  dest="$dest_dir/$name"

  if [ -d "$src" ]; then
    if [ -e "$dest" ]; then
      # Merge folders
      rsync -a --remove-source-files --ignore-existing "$src/" "$dest/"
      rmdir "$src" 2>/dev/null && log_action "DELETED EMPTY FOLDER: $src"
      log_action "MERGED FOLDER: $src → $dest"
    else
      mv "$src" "$dest_dir"
      log_action "MOVED FOLDER: $src → $dest"
    fi
  else
    mv "$src" "$dest_dir"
    log_action "MOVED FILE: $src → $dest_dir/$name"
  fi
}

# Move old items (depth = 1, older than 1 minute)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$SLIDES_ARCHIVE"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$MARKUP_ARCHIVE"
done

log_action "Archive job completed. Source files cleaned."