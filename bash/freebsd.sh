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
  echo "[$(date +%Y-%m-%d_%H:%M:%S)] $1" >> "$LOG_FILE"
}

# Safe move/merge function with source cleanup
safe_move() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir/$name"

  if [ -d "$src" ]; then
    if [ -e "$dest" ]; then
      # Merge folders, delete source files after transfer
      # Using rsync with --remove-source-files requires GNU rsync (pkg install rsync)
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --remove-source-files --ignore-existing "$src/" "$dest/"
      else
        cp -Rp "$src/." "$dest/" && rm -rf "$src/"*
      fi
      # Delete empty source folder
      rmdir "$src" 2>/dev/null && log_action "DELETED EMPTY FOLDER: $src"
      log_action "MERGED FOLDER: $src → $dest (deleted source after transfer)"
    else
      # Move new folder (standard mv)
      mv -v "$src" "$dest_dir"
      log_action "MOVED FOLDER: $src → $dest"
    fi
  else
    # Overwrite files and delete source
    mv -vf "$src" "$dest_dir"
    log_action "MOVED FILE: $src → $dest_dir/$name (deleted source)"
  fi
}

# Move OLD ITEMS (folders/files, depth=1)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -mmin +1 -print0 | while IFS= read -r -d '' item; do
  safe_move "$item" "$SLIDES_ARCHIVE"
done

find "$MARKUP_SRC" -mindepth 1 -maxdepth 1 -mmin +1 -print0 | while IFS= read -r -d '' item; do
  safe_move "$item" "$MARKUP_ARCHIVE"
done

log_action "Archive job completed. Source files cleaned."