#!/bin/bash

# Define source and archive directories
SLIDES_SRC="/mnt/datastore/test-data/images/slides"
SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"

MARKUP_SRC="/mnt/datastore/test-data/images/markup"
MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# Log directory and filename (date-stamped)
LOG_DIR="/var/log/archive_script"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"

# Create log and archive directories if they don't exist
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function (appends source → destination moves with timestamps)
log_move() {
    echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] Moved: $1 → $2" >> "$LOG_FILE"
}

# Move folders older than 1 minute (for testing) and log each move
find "$SLIDES_SRC" -mindepth 1 -type d -mmin +1 -print0 | while IFS= read -r -d '' folder; do
    dest="$SLIDES_ARCHIVE/$(basename "$folder")"
    mv -v "$folder" "$dest"
    log_move "$folder" "$dest"
done

find "$MARKUP_SRC" -mindepth 1 -type d -mmin +1 -print0 | while IFS= read -r -d '' folder; do
    dest="$MARKUP_ARCHIVE/$(basename "$folder")"
    mv -v "$folder" "$dest"
    log_move "$folder" "$dest"
done

# Final log entry
echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] Archive job completed." >> "$LOG_FILE"