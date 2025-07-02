#!/bin/sh

# Configuration
SLIDES_SRC="./Images/Slides"
SLIDES_ARCHIVE="./Images/Archive"
CONTROLS_SRC="./Images/Slides/Controls"
CONTROLS_ARCHIVE="./Images/Archive/Controls"
MARKUP_SRC="./Images/Slides/Markup"
MARKUP_ARCHIVE="./Images/Archive/Markup"
DURATION=90
MAX_SIZE=$((500 * 1024 * 1024 * 1024))  # 500 GB in bytes

# Logging setup
LOG_DIR="/mnt/tank/scripts/logs/slides-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"

# Global variables
total_moved=0
limit_reached=0

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Check if directory is empty
is_empty_dir() {
  [ -z "$(ls -A "$1")" ]
}

# Get size of folder in bytes (FreeBSD compatible)
get_folder_size() {
  du -d0 -k "$1" | awk '{print $1 * 1024}'  # Convert from KB to bytes
}

# Safe move with rsync
safe_move() {
  local src="$1"
  local dest="$2"
  local size=0
  local rsync_log=$(mktemp)

  # Get size (file or folder)
  if [ -d "$src" ]; then
    size=$(get_folder_size "$src")
  else
    size=$(stat -f %z "$src")
  fi

  # Skip if limit reached
  if [ $limit_reached -eq 1 ]; then
    return
  fi

  # Check size limit
  if [ $((total_moved + size)) -gt $MAX_SIZE ]; then
    if [ -d "$src" ]; then
      log_action "SKIPPING FOLDER: $src (size: $((size/1024/1024)) MB - would exceed 500 GB limit)"
    else
      log_action "SKIPPING FILE: $src (size: $((size/1024)) KB - would exceed 500 GB limit)"
    fi
    limit_reached=1
    return
  fi

  # Create destination directory if needed
  mkdir -p "$(dirname "$dest")"

  # Perform the move with rsync
  rsync -avh --remove-source-files --progress "$src" "$dest" > "$rsync_log" 2>&1
  local rsync_status=$?

  # Log rsync output
  cat "$rsync_log" >> "$LOG_FILE"
  rm "$rsync_log"

  # Check result
  if [ $rsync_status -eq 0 ]; then
    # Update moved size
    total_moved=$((total_moved + size))
    
    if [ -d "$src" ]; then
      log_action "MOVED FOLDER: $src → $dest ($((size/1024/1024)) MB)"
      # Remove source folder if empty
      if is_empty_dir "$src"; then
        rmdir "$src"
        log_action "REMOVED: Empty source folder $src"
      else
        log_action "WARNING: Source folder not empty after move: $src"
      fi
    else
      log_action "MOVED FILE: $src → $dest ($((size/1024)) KB)"
    fi
    
    log_action "TOTAL MOVED: $((total_moved/1024/1024/1024)) GB"
  else
    log_action "ERROR: Failed to move $src → $dest (rsync status: $rsync_status)"
  fi
}

# --- Main Execution ---
log_action "Starting archive job (Max: 500 GB)"
log_action "Current disk usage: $(df -h /mnt/tank | awk 'NR==2 {print $3 " used, " $4 " free"}')"

# Move Slides folders
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  folder_name=$(basename "$folder")
  [ $limit_reached -eq 0 ] && safe_move "$folder" "$SLIDES_ARCHIVE/$folder_name"
done

# Move Markup folders
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  folder_name=$(basename "$folder")
  [ $limit_reached -eq 0 ] && safe_move "$folder" "$MARKUP_ARCHIVE/$folder_name"
done

# Move Controls folders
find "$CONTROLS_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  folder_name=$(basename "$folder")
  [ $limit_reached -eq 0 ] && safe_move "$folder" "$CONTROLS_ARCHIVE/$folder_name"
done

# Move Slides files
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  [ $limit_reached -eq 0 ] && safe_move "$file" "$SLIDES_ARCHIVE/"
done

# Move Markup files
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  [ $limit_reached -eq 0 ] && safe_move "$file" "$MARKUP_ARCHIVE/"
done

# Final status
if [ $limit_reached -eq 1 ]; then
  log_action "Archive job PARTIALLY completed - 500 GB limit reached"
else
  log_action "Archive job FULLY completed"
fi
log_action "Total data moved: $((total_moved/1024/1024/1024)) GB"
log_action "Current disk usage: $(df -h /mnt/tank | awk 'NR==2 {print $3 " used, " $4 " free"}')"