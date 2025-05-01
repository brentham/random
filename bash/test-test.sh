#!/bin/bash

# Configuration (TESTING VERSION - 1 MINUTE)
SLIDES_SRC="./images/slides/"
SLIDES_ARCHIVE="./images/archive/slides/"
MARKUP_SRC="./images/markup/"
MARKUP_ARCHIVE="./images/archive/markup/"
MINUTES_OLD=1  # Testing with 1-minute threshold

# Logging setup
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Enhanced logging function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Function to check file age and log details (minutes-based)
check_and_log_file() {
  local src="$1"
  local dest="$2"
  local file_age_minutes=$(( ($(date +%s) - $(stat -c %Y "$src")) / 60 ))
  
  if [ $file_age_minutes -ge $MINUTES_OLD ]; then
    local size=$(du -h "$src" | cut -f1)
    local type=$(file -b --mime-type "$src" 2>/dev/null || echo "unknown")
    log_action "FILE: $src → $dest (Size: $size, Type: $type, Age: ${file_age_minutes}m)"
    return 0
  else
    log_action "SKIPPED: $src (Only ${file_age_minutes}m old)"
    return 1
  fi
}

# Move files with age verification
move_files() {
  local src="$1"
  local dest="$2"
  
  while IFS= read -r -d '' file; do
    rel_path="${file#$src}"
    dest_file="$dest$rel_path"
    mkdir -p "$(dirname "$dest_file")"
    if check_and_log_file "$file" "$dest_file"; then
      mv -v "$file" "$dest_file" >> "$LOG_FILE" 2>&1
    fi
  done < <(find "$src" -type f -print0)
}

# Smart transfer function using mv
transfer_item() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir$name"
  local file_age_minutes=$(( ($(date +%s) - $(stat -c %Y "$src")) / 60 ))

  if [ $file_age_minutes -lt $MINUTES_OLD ]; then
    log_action "SKIPPED: $src (Only ${file_age_minutes}m old)"
    return
  fi

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      log_action "START MERGE: $src → $dest (${file_age_minutes}m old)"
      move_files "$src/" "$dest/"
      find "$src" -mindepth 1 -type d -empty -delete 2>/dev/null
      log_action "END MERGE: $src → $dest"
    else
      log_action "START FOLDER MOVE: $src → $dest (${file_age_minutes}m old)"
      mkdir -p "$dest"
      move_files "$src/" "$dest/"
      rm -rf "$src"
      log_action "END FOLDER MOVE: $src → $dest"
    fi
  else
    if check_and_log_file "$src" "$dest_dir$(basename "$src")"; then
      mkdir -p "$dest_dir"
      mv -v "$src" "$dest_dir" >> "$LOG_FILE" 2>&1
    fi
  fi
}

# Main archive function (modified find command for minutes)
archive_items() {
  local src="$1"
  local dest="$2"
  
  log_action "START ARCHIVE JOB: $src → $dest (Files older than $MINUTES_OLD minutes)"
  
  # Find files older than MINUTES_OLD minutes
  find "$src" -mindepth 1 -maxdepth 1 -mmin +$MINUTES_OLD | while read -r item; do
    transfer_item "$item" "$dest"
  done
  
  log_action "END ARCHIVE JOB: $src → $dest"
}

# Execute
archive_items "$SLIDES_SRC" "$SLIDES_ARCHIVE"
archive_items "$MARKUP_SRC" "$MARKUP_ARCHIVE"

log_action "COMPLETED: Archive job finished using mv. Only items older than $MINUTES_OLD minutes were processed."