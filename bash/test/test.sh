# Safe move function (merges folders, overwrites files)
safe_move() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir/$name"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      # Merge folders (skip existing files, log conflicts)
      rsync -a --ignore-existing "$src/" "$dest/"
      log_action "MERGED FOLDER: $src → $dest (merged contents)"
    else
      # Move new folder
      mv -v "$src" "$dest_dir"
      log_action "MOVED FOLDER: $src → $dest"
    fi
  else
    # Overwrite files
    mv -vf "$src" "$dest_dir"
    log_action "MOVED FILE: $src → $dest_dir/$name"
  fi
}

# Move OLD FOLDERS (depth=1)
find "$SLIDES_SRC" -mindepth 1 -maxdepth 1 -mmin +1 | while read -r item; do
  safe_move "$item" "$SLIDES_ARCHIVE"
done