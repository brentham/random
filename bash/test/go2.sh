#!/bin/bash

# Configuration
SLIDES_SRC="./images/slides/"
SLIDES_ARCHIVE="./images/archive/slides/"
MARKUP_SRC="./images/markup/"
MARKUP_ARCHIVE="./images/archive/markup/"

# Logging setup
LOG_DIR="./var/log/archive_script"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Safe move/merge function with source cleanup
safe_move() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir/$name"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      # Log conflict (no merge without rsync)
      log_action "SKIPPED FOLDER (already exists): $src → $dest"
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

# Move OLD ITEMS (folders/files, depth=1)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$SLIDES_ARCHIVE"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$MARKUP_ARCHIVE"
done

log_action "Archive job completed (no source files deleted)."