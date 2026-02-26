#!/usr/bin/env bash
# Shared functions for memory capture scripts
# Sourced by: capture-text.sh, capture-screen.sh, capture-audio.sh
# SYSTEM_NAME is replaced by install.sh via sed

# --- Directory Paths ---

MEMORIES_DIR="$HOME/.SYSTEM_NAME/files/memories"
ASSETS_DIR="$MEMORIES_DIR/assets"
export SYS_DIR="$HOME/.SYSTEM_NAME/.sys"
KHOJ_PORT=9371

# --- Timestamp Generation ---

# Generate timestamp in YYYYMMDD_HHMMSS format
generate_timestamp() {
  date +"%Y%m%d_%H%M%S"
}

# --- YAML Front-Matter Writer ---

# Write YAML front-matter to a file
# Args: $1=file_path, $2=type, $3=source, $4=timestamp
write_frontmatter() {
  local file="$1"
  local mem_type="$2"
  local source="$3"
  local timestamp="$4"

  # Format YYYYMMDD_HHMMSS → YYYY-MM-DD HH:MM:SS using parameter expansion
  local display_date
  display_date="${timestamp:0:4}-${timestamp:4:2}-${timestamp:6:2} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}"

  # Format date for heading: YYYY-MM-DD
  local heading_date="${timestamp:0:4}-${timestamp:4:2}-${timestamp:6:2}"

  cat > "$file" <<FRONTMATTER
---
type: ${mem_type}
captured: ${display_date}
source: ${source}
---

# ${heading_date}

FRONTMATTER
}

# --- Memories Directory Resolver ---

# Ensure memories directory exists
ensure_memories_dir() {
  if [[ ! -d "$MEMORIES_DIR" ]]; then
    echo "Error: cannot write to memories directory" >&2
    exit 1
  fi
}

# Ensure assets directory exists
ensure_assets_dir() {
  if [[ ! -d "$ASSETS_DIR" ]]; then
    mkdir -p "$ASSETS_DIR"
  fi
}

# --- Async Reindex Trigger ---

# Trigger Khoj to re-index (best-effort, non-blocking)
trigger_reindex() {
  curl -s -X POST "http://localhost:${KHOJ_PORT}/api/update?t=markdown" \
    > /dev/null 2>&1 &
}

# --- Temp File Cleanup ---

# Clean up a list of temp files (dot-prefixed, in /tmp/)
cleanup_temp_files() {
  for tmpfile in "$@"; do
    if [[ -f "$tmpfile" ]]; then
      rm -f "$tmpfile"
    fi
  done
}
