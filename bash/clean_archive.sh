#!/bin/sh

# Set your archive directory path here
ARCHIVE_DIR="/path/to/archive"
# Remove trailing slash if present
ARCHIVE_DIR="${ARCHIVE_DIR%/}"

# Check if directory exists
if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "Error: Directory $ARCHIVE_DIR does not exist" >&2
    exit 1
fi

# Define the absolute paths of the folders to preserve
PRESERVE1="$ARCHIVE_DIR/Controls"
PRESERVE2="$ARCHIVE_DIR/Markup"

# Find and remove empty directories (preserving only the top-level Controls/Markup)
find "$ARCHIVE_DIR" -depth -type d -empty | while read -r dir; do
    # Skip the specific preserve directories
    if [ "$dir" = "$PRESERVE1" ] || [ "$dir" = "$PRESERVE2" ]; then
        echo "Preserved top-level directory: $dir"
        continue
    fi
    
    # Remove the empty directory
    if rmdir "$dir" 2>/dev/null; then
        echo "Removed: $dir"
    fi
done