#!/usr/bin/env bash
# Save text input as a timestamped markdown memory file
# Usage: capture-text.sh <text_content>
# SYSTEM_NAME is replaced by install.sh via sed
set -e

# shellcheck source=capture-common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/capture-common.sh"

# --- Input Validation ---

if [[ -z "${1:-}" ]]; then
  echo "Error: empty text" >&2
  exit 1
fi

TEXT_CONTENT="$1"

# --- Main ---

ensure_memories_dir

TIMESTAMP="$(generate_timestamp)"
FILENAME="mem_${TIMESTAMP}_text.md"
FILEPATH="${MEMORIES_DIR}/${FILENAME}"

# Write markdown with YAML front-matter
write_frontmatter "$FILEPATH" "text" "quick-capture" "$TIMESTAMP"

# Append the text content as the body
echo "$TEXT_CONTENT" >> "$FILEPATH"

# Trigger async re-index (best-effort)
trigger_reindex

# Output created file path to stdout
echo "$FILEPATH"
