#!/bin/bash

# Define source and archive directories
SLIDES_SRC="/mnt/datastore/test-data/images/slides"
SLIDES_ARCHIVE="/mnt/datastore/test-data/images/archive"

MARKUP_SRC="/mnt/datastore/test-data/images/markup"
MARKUP_ARCHIVE="/mnt/datastore/test-data/markup/archive"

# Create archive directories if they don't exist
mkdir -p "$SLIDES_ARCHIVE" "$MARKUP_ARCHIVE"

# Move files older than 60 days from SLIDES_SRC to SLIDES_ARCHIVE
find "$SLIDES_SRC" -type f -mtime +60 -exec mv -v {} "$SLIDES_ARCHIVE" \;

# Move files older than 60 days from MARKUP_SRC to MARKUP_ARCHIVE
find "$MARKUP_SRC" -type f -mtime +60 -exec mv -v {} "$MARKUP_ARCHIVE" \;

# Optional: Log the operation
echo "[$(date)] Files older than 60 days moved to archive." >> /var/log/archive_script.log