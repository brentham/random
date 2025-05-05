safe_move() {
  local src="$1"
  local dest_dir="$2"
  local name="$(basename "$src")"
  local dest="$dest_dir/$name"

  if [[ -d "$src" ]]; then
    if [[ -e "$dest" ]]; then
      # Delete source folder (even if destination exists)
      rm -rf "$src"
      log_action "DELETED SOURCE FOLDER (destination exists): $src"
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