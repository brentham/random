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

# Move folder without nesting
move_folder() {
  local src="$1"
  local dest_dir="$2"
  local folder_name=$(basename "$src")
  local dest_path="$dest_dir/$folder_name"
  
  # If destination exists, move contents instead of folder
  if [[ -d "$dest_path" ]]; then
    log_action "MERGING: Moving contents of $src to existing $dest_path"
    # Move all items from source to destination
    find "$src" -mindepth 1 -maxdepth 1 -exec mv -v "{}" "$dest_path" \; >> "$LOG_FILE" 2>&1
    # Remove the now empty source folder
    rmdir "$src"
  else
    # Destination doesn't exist, move entire folder
    mv -v "$src" "$dest_dir" >> "$LOG_FILE" 2>&1
    log_action "MOVED FOLDER: $src → $dest_path"
  fi
}

# Move file with conflict resolution
move_file() {
  local src="$1"
  local dest_dir="$2"
  local file_name=$(basename "$src")
  local dest_path="$dest_dir/$file_name"
  
  # Handle existing files
  if [[ -e "$dest_path" ]]; then
    # Generate new name with timestamp
    local timestamp=$(date +%Y%m%d%H%M%S)
    local new_name="${file_name%.*}-${timestamp}.${file_name##*.}"
    dest_path="$dest_dir/$new_name"
    log_action "RENAMED FILE: $file_name → $new_name (conflict resolved)"
  fi

  # Perform the move
  mv -v "$src" "$dest_path" >> "$LOG_FILE" 2>&1
  log_action "MOVED FILE: $src → $dest_path"
}

# --- Main Execution ---
log_action "Starting archive job"

# Move Slides folders
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  move_folder "$folder" "$SLIDES_ARCHIVE"
done

# Move Markup folders
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  move_folder "$folder" "$MARKUP_ARCHIVE"
done

# Move Controls folders
find "$CONTROLS_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  move_folder "$folder" "$CONTROLS_ARCHIVE"
done

# Move Slides files
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  move_file "$file" "$SLIDES_ARCHIVE"
done

# Move Markup files
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  move_file "$file" "$MARKUP_ARCHIVE"
done

log_action "Archive job completed"