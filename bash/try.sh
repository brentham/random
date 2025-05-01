#!/bin/bash

# Configuration Variables
SOURCE_SLIDES="/mnt/datastore/test-data/images/slides/"
DEST_SLIDES="/mnt/datastore/test-data/images/archive/"

SOURCE_MARKUP="/mnt/datastore/test-data/images/markup/"
DEST_MARKUP="/mnt/datastore/test-data/markup/archive/"

LOG_DIR="/var/log/archive_script"
LOG_DATE=$(date +"%Y-%m-%d")
LOG_FILE="${LOG_DIR}/archive_script-${LOG_DATE}.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" || {
    echo "[$TIMESTAMP] ERROR: Failed to create log directory $LOG_DIR" >&2
    exit 1
}

# Function to archive folders older than 60 days
archive_folders() {
    local source_path="$1"
    local dest_path="$2"
    local folder_type="$3"
    
    echo "[$TIMESTAMP] Processing $folder_type folders..." >> "$LOG_FILE"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dest_path" || {
        echo "[$TIMESTAMP] ERROR: Failed to create $folder_type destination directory $dest_path" >> "$LOG_FILE"
        return 1
    }
    
    # Find folders older than 60 days and move them
    find "$source_path" -mindepth 1 -maxdepth 1 -type d -mtime +60 -print0 | while IFS= read -r -d $'\0' folder; do
        folder_name=$(basename "$folder")
        echo "[$TIMESTAMP] ARCHIVING: Moving $folder_name from $source_path to $dest_path" >> "$LOG_FILE"
        
        mv -v "$folder" "$dest_path" >> "$LOG_FILE" 2>&1 || {
            echo "[$TIMESTAMP] ERROR: Failed to move $folder_name to $dest_path" >> "$LOG_FILE"
        }
    done
}

# Main execution
echo "[$TIMESTAMP] STARTING ARCHIVE SCRIPT" >> "$LOG_FILE"
echo "[$TIMESTAMP] Source Slides: $SOURCE_SLIDES" >> "$LOG_FILE"
echo "[$TIMESTAMP] Destination Slides: $DEST_SLIDES" >> "$LOG_FILE"
echo "[$TIMESTAMP] Source Markup: $SOURCE_MARKUP" >> "$LOG_FILE"
echo "[$TIMESTAMP] Destination Markup: $DEST_MARKUP" >> "$LOG_FILE"

# Archive slides folders
archive_folders "$SOURCE_SLIDES" "$DEST_SLIDES" "slides"

# Archive markup folders
archive_folders "$SOURCE_MARKUP" "$DEST_MARKUP" "markup"

echo "[$TIMESTAMP] ARCHIVE SCRIPT COMPLETED" >> "$LOG_FILE"