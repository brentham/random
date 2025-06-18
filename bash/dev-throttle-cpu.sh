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
MAX_CPU_LOAD=60           # Max system CPU load percentage before pausing
IO_NICE_CLASS=3           # I/O priority class (3=idle)
IO_NICE_LEVEL=7           # I/O priority level (0-7, 7=lowest)
NICE_LEVEL=19             # CPU nice level (19=lowest priority)
SLEEP_BETWEEN_OPS=2       # Seconds to sleep between operations
SLEEP_AT_HIGH_LOAD=30     # Seconds to sleep when system load is high
MAX_ITEMS_PER_RUN=50      # Maximum items to process per source per run

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

# Function to move items with resource limits
move_items() {
  local src="$1"
  local dest="$2"
  local item_type="$3"
  local description="$4"
  local processed=0
  local total=0

  # Count total items first to show progress
  total=$(find "$src" -mindepth 1 -maxdepth 1 -type "$item_type" -mtime +$DURATION | wc -l)
  log_action "Processing $total $description in $src"

  # Find and process items
  find "$src" -mindepth 1 -maxdepth 1 -type "$item_type" -mtime +$DURATION | while read -r item; do
    # Resource limit checks
    if [ $processed -ge $MAX_ITEMS_PER_RUN ]; then
      log_action "MAX ITEMS REACHED: Processed $MAX_ITEMS_PER_RUN $description from $src"
      break
    fi
    
    current_load=$(get_cpu_load)
    if (( $(echo "$current_load > $MAX_CPU_LOAD" | bc -l) )); then
      log_action "HIGH LOAD PAUSE: System load ${current_load}% > ${MAX_CPU_LOAD}% - sleeping ${SLEEP_AT_HIGH_LOAD}s"
      sleep $SLEEP_AT_HIGH_LOAD
    fi
    
    # Execute move with low priority
    item_name=$(basename "$item")
    if [ "$item_type" = "d" ]; then
      dest_path="$dest/$item_name"
    else
      dest_path="$dest"
    fi
    
    # Move with resource priorities
    ionice -c $IO_NICE_CLASS -n $IO_NICE_LEVEL nice -n $NICE_LEVEL mv -v "$item" "$dest_path" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
      log_action "MOVED $description: $item → $dest_path"
    else
      log_action "FAILED $description: $item → $dest_path"
    fi
    
    # Increment counter and pause
    ((processed++))
    sleep $SLEEP_BETWEEN_OPS
  done
  
  log_action "Processed $processed/$total $description from $src"
}

# Start log
log_action "===== STARTING ARCHIVE JOB (DURATION: $DURATION days) ====="
log_action "Resource Limits: MAX_CPU_LOAD=${MAX_CPU_LOAD}% NICE=${NICE_LEVEL} IONICE=c${IO_NICE_CLASS}n${IO_NICE_LEVEL}"
log_action "Rate Limits: SLEEP=${SLEEP_BETWEEN_OPS}s MAX_ITEMS=${MAX_ITEMS_PER_RUN}"

# Process folders
move_items "$SLIDES_SRC" "$SLIDES_ARCHIVE" "d" "slide folders"
move_items "$MARKUP_SRC" "$MARKUP_ARCHIVE" "d" "markup folders"
move_items "$CONTROLS_SRC" "$CONTROLS_ARCHIVE" "d" "control folders"

# Process files
move_items "$SLIDES_SRC" "$SLIDES_ARCHIVE" "f" "slide files"
move_items "$MARKUP_SRC" "$MARKUP_ARCHIVE" "f" "markup files"

# Completion
log_action "Archive job completed with resource limits."