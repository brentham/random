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

# Enhanced logging function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Function to log file details
log_file() {
  local src="$1"
  local dest="$2"
  local size=$(du -h "$src" | cut -f1)
  local type=$(file -b --mime-type "$src" 2>/dev/null || echo "unknown")
  log_action "FILE: $src → $dest"
}

# Process rsync output and log files
process_rsync() {
  local src="$1"
  local dest="$2"
  
  # First pass - log all files being moved
  while IFS= read -r -d '' file; do
    rel_path="${file#$src}"
    dest_file="$dest$rel_path"
    log_file "$file" "$dest_file"
  done < <(find "$src" -type f -print0)
  
  # Second pass - actually perform the move
  rsync -a --remove-source-files "$src" "$dest"
}

# Smart transfer function
transfer_item() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir$name"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      log_action "START MERGE: $src → $dest"
      process_rsync "$src/" "$dest/"
      find "$src" -mindepth 1 -type d -empty -delete 2>/dev/null
      log_action "END MERGE: $src → $dest (merged)"
    else
      log_action "START FOLDER MOVE: $src → $dest"
      process_rsync "$src/" "$dest/"
      rm -rf "$src"
      log_action "END FOLDER MOVE: $src → $dest"
    fi
  else
    # Handle individual files
    log_file "$src" "$dest_dir$(basename "$src")"
    rsync -a --remove-source-files "$src" "$dest_dir" && rm -f "$src"
  fi
}

# Main archive function
archive_items() {
  local src="$1"
  local dest="$2"
  
  log_action "START ARCHIVE JOB: $src → $dest"
  
  find "$src" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
    transfer_item "$item" "$dest"
  done
  
  log_action "END ARCHIVE JOB: $src → $dest"
}

# Execute
archive_items "$SLIDES_SRC" "$SLIDES_ARCHIVE"
archive_items "$MARKUP_SRC" "$MARKUP_ARCHIVE"

log_action "COMPLETED: Archive job finished. Files logged."