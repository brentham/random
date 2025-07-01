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

# Get size of folder in bytes (FreeBSD compatible)
get_folder_size() {
  # Use -d0 to get total for the directory itself
  du -d0 -k "$1" | awk '{print $1 * 1024}'  # Convert from KB to bytes
}

# Move folder without nesting
move_folder() {
  local src="$1"
  local dest_dir="$2"
  local folder_name=$(basename "$src")
  local dest_path="$dest_dir/$folder_name"
  local size=0

  # Skip if limit already reached
  if [ $limit_reached -eq 1 ]; then
    return
  fi

  # Get folder size (FreeBSD compatible)
  size=$(get_folder_size "$src")
  
  # Check if moving would exceed limit
  if [ $((total_moved + size)) -gt $MAX_SIZE ]; then
    log_action "SKIPPING: $folder_name (size: $((size/1024/1024)) MB - would exceed 500 GB limit)"
    limit_reached=1
    return
  fi

  # If destination exists, move contents instead of folder
  if [ -d "$dest_path" ]; then
    log_action "MERGING: Moving contents of $folder_name to existing folder"
    find "$src" -mindepth 1 -maxdepth 1 -exec mv -v "{}" "$dest_path" \; >> "$LOG_FILE" 2>&1
    # Remove the now empty source folder
    rmdir "$src"
  else
    # Destination doesn't exist, move entire folder
    mv -v "$src" "$dest_dir" >> "$LOG_FILE" 2>&1
    log_action "MOVED FOLDER: $folder_name → $dest_dir"
  fi
  
  # Update total moved
  total_moved=$((total_moved + size))
  log_action "MOVED: $folder_name ($((size/1024/1024)) MB) - Total: $((total_moved/1024/1024/1024)) GB"
}

# Move file with conflict resolution
move_file() {
  local src="$1"
  local dest_dir="$2"
  local file_name=$(basename "$src")
  local dest_path="$dest_dir/$file_name"
  local size=0

  # Skip if limit already reached
  if [ $limit_reached -eq 1 ]; then
    return
  fi

  # Get file size (FreeBSD compatible)
  size=$(stat -f %z "$src")
  
  # Check if moving would exceed limit
  if [ $((total_moved + size)) -gt $MAX_SIZE ]; then
    log_action "SKIPPING: $file_name (size: $((size/1024)) KB - would exceed 500 GB limit)"
    limit_reached=1
    return
  fi

  # Handle existing files
  if [ -e "$dest_path" ]; then
    # Generate new name with timestamp
    local timestamp=$(date +%Y%m%d%H%M%S)
    local base="${file_name%.*}"
    local ext="${file_name##*.}"
    # If there's no extension, avoid a trailing dot
    if [ "$base" = "$file_name" ]; then
      ext=""
    else
      ext=".$ext"
    fi
    local new_name="${base}-${timestamp}${ext}"
    dest_path="$dest_dir/$new_name"
    log_action "RENAMED FILE: $file_name → $new_name (conflict resolved)"
  fi

  # Perform the move
  mv -v "$src" "$dest_path" >> "$LOG_FILE" 2>&1
  log_action "MOVED FILE: $file_name → $dest_path"
  
  # Update total moved
  total_moved=$((total_moved + size))
  log_action "MOVED: $file_name ($((size/1024)) KB) - Total: $((total_moved/1024/1024/1024)) GB"
}

# --- Main Execution ---
log_action "Starting archive job (Max: 500 GB)"
log_action "Current disk usage: $(df -h /mnt/tank | awk 'NR==2 {print $3 " used, " $4 " free"}')"

# Move Slides folders
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  [ $limit_reached -eq 0 ] && move_folder "$folder" "$SLIDES_ARCHIVE"
done

# Move Markup folders
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  [ $limit_reached -eq 0 ] && move_folder "$folder" "$MARKUP_ARCHIVE"
done

# Move Controls folders
find "$CONTROLS_SRC" -mindepth 1 -maxdepth 1 -type d -mtime +$DURATION | while read -r folder; do
  [ $limit_reached -eq 0 ] && move_folder "$folder" "$CONTROLS_ARCHIVE"
done

# Move Slides files
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  [ $limit_reached -eq 0 ] && move_file "$file" "$SLIDES_ARCHIVE"
done

# Move Markup files
find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -type f -mtime +$DURATION | while read -r file; do
  [ $limit_reached -eq 0 ] && move_file "$file" "$MARKUP_ARCHIVE"
done

# Final status
if [ $limit_reached -eq 1 ]; then
  log_action "Archive job PARTIALLY completed - 500 GB limit reached"
else
  log_action "Archive job FULLY completed"
fi
log_action "Total data moved: $((total_moved/1024/1024/1024)) GB"
log_action "Current disk usage: $(df -h /mnt/tank | awk 'NR==2 {print $3 " used, " $4 " free"}')"