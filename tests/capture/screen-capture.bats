#!/usr/bin/env bats
# Tests for scripts/capture-screen.sh
# T013: Contract tests — file naming (md + png), PNG moved to assets/,
#        markdown references image, annotation in body
# T014: Error-handling tests — missing image, zero-size image, temp cleanup
# Spec IDs: TS-011, TS-013, TS-014, TS-016, TS-017, TS-018, TS-019

load helpers/setup

# --- Setup & Teardown ---

setup() {
  setup_test_env
  mock_reindex

  # Create wrapper that overrides paths
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)"
  WRAPPER="$TEST_TMPDIR/capture-screen-wrapper.sh"
  cat > "$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -e

# Override capture-common.sh variables
export MEMORIES_DIR="$MEMORIES_DIR"
export ASSETS_DIR="$ASSETS_DIR"
export SYS_DIR="$SYS_DIR"
KHOJ_PORT=9371

# Source shared functions
SCRIPT_DIR="$SCRIPT_DIR"
source "\$SCRIPT_DIR/capture-common.sh"

# Re-override after source
MEMORIES_DIR="$MEMORIES_DIR"
ASSETS_DIR="$ASSETS_DIR"

# --- Input Validation ---
TEMP_IMAGE="\${1:-}"
ANNOTATION="\${2:-}"

if [[ -z "\$TEMP_IMAGE" ]] || [[ ! -f "\$TEMP_IMAGE" ]]; then
  echo "Error: image not found" >&2
  exit 1
fi

if [[ ! -s "\$TEMP_IMAGE" ]]; then
  echo "Error: image is empty" >&2
  exit 1
fi

# --- Main ---
ensure_memories_dir
ensure_assets_dir

TIMESTAMP="\$(generate_timestamp)"
ASSET_FILENAME="scr_\${TIMESTAMP}.png"
ASSET_PATH="\${ASSETS_DIR}/\${ASSET_FILENAME}"
MD_FILENAME="mem_\${TIMESTAMP}_screenshot.md"
MD_FILEPATH="\${MEMORIES_DIR}/\${MD_FILENAME}"

if ! mv "\$TEMP_IMAGE" "\$ASSET_PATH"; then
  echo "Error: cannot move image to assets" >&2
  exit 1
fi

write_frontmatter "\$MD_FILEPATH" "screenshot" "screen-capture" "\$TIMESTAMP"

if [[ -n "\$ANNOTATION" ]]; then
  echo "\$ANNOTATION" >> "\$MD_FILEPATH"
  echo "" >> "\$MD_FILEPATH"
fi

echo "![screenshot](assets/\${ASSET_FILENAME})" >> "\$MD_FILEPATH"
trigger_reindex
echo "\$MD_FILEPATH"
WRAPPER_EOF
  chmod +x "$WRAPPER"
}

teardown() {
  teardown_test_env
}

# ============================================================
# T013: Contract Tests [TS-016, TS-019]
# ============================================================

@test "T013: screen capture creates markdown file with correct naming pattern" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  [ -f "$filepath" ]

  local filename
  filename="$(basename "$filepath")"
  [[ "$filename" =~ ^mem_[0-9]{8}_[0-9]{6}_screenshot\.md$ ]]
}

@test "T013: screen capture moves PNG to assets directory" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  # Original file should be gone (moved)
  [ ! -f "$img" ]

  # Asset should exist in assets/
  assert_file_matches_pattern "$ASSETS_DIR" "scr_*_*.png"
}

@test "T013: screen capture PNG in assets has correct naming pattern" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local asset
  asset=$(find "$ASSETS_DIR" -name "scr_*.png" | head -1)
  [ -n "$asset" ]

  local asset_name
  asset_name="$(basename "$asset")"
  [[ "$asset_name" =~ ^scr_[0-9]{8}_[0-9]{6}\.png$ ]]
}

@test "T013: markdown references image with relative path" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  # Should contain image reference with relative assets/ path
  grep -q '!\[screenshot\](assets/scr_' "$filepath"
}

@test "T013: screen capture sets type field to 'screenshot'" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_frontmatter_field "$filepath" "type" "screenshot"
}

@test "T013: screen capture sets source field to 'screen-capture'" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_frontmatter_field "$filepath" "source" "screen-capture"
}

@test "T013: screen capture writes valid YAML front-matter" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_valid_frontmatter "$filepath"
}

@test "T013: annotation is included in markdown body" {
  local img
  img="$(create_test_png)"
  local note="This is my screenshot note"

  run bash "$WRAPPER" "$img" "$note"
  [ "$status" -eq 0 ]

  local filepath="$output"
  grep -q "$note" "$filepath"
}

@test "T013: screenshot without annotation still creates valid markdown" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_valid_frontmatter "$filepath"
  grep -q '!\[screenshot\]' "$filepath"
}

@test "T013: screen capture exits with code 0 on success" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]
}

# ============================================================
# T014: Error-Handling Tests [TS-017, TS-018]
# ============================================================

@test "T014: screen capture rejects missing image path with exit 1" {
  run bash "$WRAPPER"
  [ "$status" -eq 1 ]
}

@test "T014: screen capture rejects non-existent image with exit 1" {
  run bash "$WRAPPER" "/nonexistent/path/image.png"
  [ "$status" -eq 1 ]
}

@test "T014: screen capture writes error to stderr on missing image" {
  run bash "$WRAPPER" "/nonexistent/path/image.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "T014: screen capture rejects zero-size image with exit 1" {
  local empty_img
  empty_img="$(create_empty_file "$TEST_TMPDIR/empty.png")"

  run bash "$WRAPPER" "$empty_img"
  [ "$status" -eq 1 ]
}

@test "T014: screen capture writes error to stderr on zero-size image" {
  local empty_img
  empty_img="$(create_empty_file "$TEST_TMPDIR/empty.png")"

  run bash "$WRAPPER" "$empty_img"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"empty"* ]]
}

@test "T014: original temp image is removed after successful capture" {
  local img
  img="$(create_test_png)"

  run bash "$WRAPPER" "$img"
  [ "$status" -eq 0 ]

  # Original temp file should be gone (mv removes source)
  [ ! -f "$img" ]
}
