#!/bin/bash

# Configuration
SLIDES_SRC="./Images/Slides"
SLIDES_ARCHIVE="./Images/Archive"
CONTROLS_SRC="./Images/Slides/Controls"
CONTROLS_ARCHIVE="./Images/Archive/Controls"
MARKUP_SRC="./Images/Slides/Markup"
MARKUP_ARCHIVE="./Images/Archive/Markup"
DURATION=60

# Resource Management Settings
MAX_CPU_LOAD=60              # Max system CPU load percentage before pausing
IO_NICE_CLASS=3              # I/O priority class (3=idle)
IO_NICE_LEVEL=7              # I/O priority level (0-7, 7=lowest)
NICE_LEVEL=19                # CPU nice level (19=lowest priority)
SLEEP_BETWEEN_OPS=2          # Seconds to sleep between operations
SLEEP_AT_HIGH_LOAD=30        # Seconds to sleep when system load is high
MAX_DATA_MOVED=$((500*1024**3)) # 500 GB in bytes (500 * 1024^3)
DATA_MOVED=0                 # Track bytes moved

# Logging setup
LOG_DIR="/mnt/tank/scripts/logs/slides-logs"
LOG_FILE="$LOG_DIR/archive_script-$(date +\%Y-\%m-\%d).log"
mkdir -p "$LOG_DIR" "$SLIDES_ARCHIVE" "$CONTROLS_ARCHIVE" "$MARKUP_ARCHIVE"

# Log function
log_action() {
  echo "[$(date +\%Y-\%m-\%d_\%H:\%M:\%S)] $1" >> "$LOG_FILE"
}

# Function to get current system load
get_cpu_load() {
  awk '{print $1}' /proc/loadavg
}

# Function to get directory size in bytes
get_size() {
  du -sb "$1" 2>/dev/null | awk '{print $1}'
}

# Function to move items with resource limits
move_items() {
  local src="$1"
  local dest="$2"
  local item_type="$3"
  local description="$4"
  local processed=0
  local total=0
  local size=0

  # Count total items first to show progress
  total=$(find "$src" -mindepth 1 -maxdepth 1 -type "$item_type" -mtime +$DURATION | wc -l)
  log_action "Processing $total $description in $src"

  # Process using file descriptor to avoid subshell issues
  while IFS= read -r -d $'\n' item; do
    # Check data limit
    if [ $DATA_MOVED -ge $MAX_DATA_MOVED ]; then
      log_action "DATA LIMIT REACHED: $((DATA_MOVED/1024**3))GB moved (max $((MAX_DATA_MOVED/1024**3))GB)"
      return 1
    fi
    
    # Check system load
    current_load=$(get_cpu_load)
    if (( $(echo "$current_load > $MAX_CPU_LOAD" | bc -l) )); then
      log_action "HIGH LOAD PAUSE: System load ${current_load}% > ${MAX_CPU_LOAD}% - sleeping ${SLEEP_AT_HIGH_LOAD}s"
      sleep $SLEEP_AT_HIGH_LOAD
    fi
    
    # Get item size
    if [ "$item_type" = "d" ]; then
      size=$(get_size "$item")
      dest_path="$dest/$(basename "$item")"
    else
      size=$(stat -c %s "$item" 2>/dev/null)
      dest_path="$dest"
    fi
    
    # Skip if we couldn't get size
    if [ -z "$size" ] || [ "$size" -le 0 ]; then
      log_action "WARNING: Could not get size for $item - skipping"
      continue
    fi
    
    # Check if this item would exceed data limit
    if [ $((DATA_MOVED + size)) -gt $MAX_DATA_MOVED ]; then
      log_action "SKIPPING: $item (size $((size/1024**2))MB) would exceed data limit"
      continue
    fi
    
    # Execute move with low priority
    ionice -c $IO_NICE_CLASS -n $IO_NICE_LEVEL nice -n $NICE_LEVEL mv -v "$item" "$dest_path" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
      log_action "MOVED $description: $item → $dest_path ($((size/1024**2))MB)"
      DATA_MOVED=$((DATA_MOVED + size))
      ((processed++))
    else
      log_action "FAILED: $item → $dest_path"
    fi
    
    # Sleep between operations
    sleep $SLEEP_BETWEEN_OPS
  done < <(find "$src" -mindepth 1 -maxdepth 1 -type "$item_type" -mtime +$DURATION -print0 | \
           xargs -0 -I{} sh -c 'echo "{}"')
  
  log_action "Processed $processed/$total $description from $src ($((DATA_MOVED/1024**3))GB total)"
}

# Start log
log_action "===== STARTING ARCHIVE JOB (DURATION: $DURATION days) ====="
log_action "Resource Limits: MAX_CPU_LOAD=${MAX_CPU_LOAD}% NICE=${NICE_LEVEL} IONICE=c${IO_NICE_CLASS}n${IO_NICE_LEVEL}"
log_action "Data Limit: $((MAX_DATA_MOVED/1024**3))GB"
log_action "Throttling: SLEEP=${SLEEP_BETWEEN_OPS}s"

# Process folders
move_items "$SLIDES_SRC" "$SLIDES_ARCHIVE" "d" "slide folders"
move_items "$MARKUP_SRC" "$MARKUP_ARCHIVE" "d" "markup folders"
move_items "$CONTROLS_SRC" "$CONTROLS_ARCHIVE" "d" "control folders"

# Process files
move_items "$SLIDES_SRC" "$SLIDES_ARCHIVE" "f" "slide files"
move_items "$MARKUP_SRC" "$MARKUP_ARCHIVE" "f" "markup files"

# Completion
log_action "Archive job completed. Total data moved: $((DATA_MOVED/1024**3))GB"