#!/usr/bin/env bash
# Save a screenshot image and create a referencing markdown memory file
# Usage: capture-screen.sh <temp_image_path> [annotation_text]
# SYSTEM_NAME is replaced by install.sh via sed
set -e

# shellcheck source=capture-common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/capture-common.sh"

# --- Input Validation ---

TEMP_IMAGE="${1:-}"
ANNOTATION="${2:-}"

if [[ -z "$TEMP_IMAGE" ]] || [[ ! -f "$TEMP_IMAGE" ]]; then
  echo "Error: image not found" >&2
  exit 1
fi

if [[ ! -s "$TEMP_IMAGE" ]]; then
  echo "Error: image is empty" >&2
  exit 1
fi

# --- Main ---

ensure_memories_dir
ensure_assets_dir

TIMESTAMP="$(generate_timestamp)"
ASSET_FILENAME="scr_${TIMESTAMP}.png"
ASSET_PATH="${ASSETS_DIR}/${ASSET_FILENAME}"
MD_FILENAME="mem_${TIMESTAMP}_screenshot.md"
MD_FILEPATH="${MEMORIES_DIR}/${MD_FILENAME}"

# Move image to assets
if ! mv "$TEMP_IMAGE" "$ASSET_PATH"; then
  echo "Error: cannot move image to assets" >&2
  exit 1
fi

# Write markdown with YAML front-matter
write_frontmatter "$MD_FILEPATH" "screenshot" "screen-capture" "$TIMESTAMP"

# Add annotation if provided
if [[ -n "$ANNOTATION" ]]; then
  echo "$ANNOTATION" >> "$MD_FILEPATH"
  echo "" >> "$MD_FILEPATH"
fi

# Add image reference with relative path
echo "![screenshot](assets/${ASSET_FILENAME})" >> "$MD_FILEPATH"

# Trigger async re-index (best-effort)
trigger_reindex

# Output created file path to stdout
echo "$MD_FILEPATH"
