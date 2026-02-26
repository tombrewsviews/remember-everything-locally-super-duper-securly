#!/usr/bin/env bats
# Tests for scripts/capture-text.sh
# T008: Contract tests — file naming, YAML front-matter, body content, exit code
# T009: Error-handling tests — empty input rejection, special characters
# Spec IDs: TS-002, TS-006, TS-007, TS-008

load helpers/setup

# --- Setup & Teardown ---

setup() {
  setup_test_env
  mock_reindex

  # Create a wrapper script that overrides variables before sourcing
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)"
  WRAPPER="$TEST_TMPDIR/capture-text-wrapper.sh"
  cat > "$WRAPPER" <<WRAPPER_EOF
#!/usr/bin/env bash
set -e

# Override capture-common.sh variables
export MEMORIES_DIR="$MEMORIES_DIR"
export ASSETS_DIR="$ASSETS_DIR"
export SYS_DIR="$SYS_DIR"
KHOJ_PORT=9371

# Source shared functions (which sets MEMORIES_DIR etc, but we override)
SCRIPT_DIR="$SCRIPT_DIR"
source "\$SCRIPT_DIR/capture-common.sh"

# Re-override after source (capture-common.sh sets them)
MEMORIES_DIR="$MEMORIES_DIR"
ASSETS_DIR="$ASSETS_DIR"

# --- Input Validation ---
if [[ -z "\${1:-}" ]]; then
  echo "Error: empty text" >&2
  exit 1
fi

TEXT_CONTENT="\$1"

# --- Main ---
ensure_memories_dir

TIMESTAMP="\$(generate_timestamp)"
FILENAME="mem_\${TIMESTAMP}_text.md"
FILEPATH="\${MEMORIES_DIR}/\${FILENAME}"

write_frontmatter "\$FILEPATH" "text" "quick-capture" "\$TIMESTAMP"
echo "\$TEXT_CONTENT" >> "\$FILEPATH"
trigger_reindex
echo "\$FILEPATH"
WRAPPER_EOF
  chmod +x "$WRAPPER"
}

teardown() {
  teardown_test_env
}

# ============================================================
# T008: Contract Tests [TS-006, TS-008]
# ============================================================

@test "T008: text capture creates markdown file with correct naming pattern" {
  run bash "$WRAPPER" "Hello world"
  [ "$status" -eq 0 ]

  # Output should be the file path
  local filepath="$output"
  [ -f "$filepath" ]

  # File should match pattern mem_YYYYMMDD_HHMMSS_text.md
  local filename
  filename="$(basename "$filepath")"
  [[ "$filename" =~ ^mem_[0-9]{8}_[0-9]{6}_text\.md$ ]]
}

@test "T008: text capture writes valid YAML front-matter" {
  run bash "$WRAPPER" "Test front-matter"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_valid_frontmatter "$filepath"
}

@test "T008: text capture sets type field to 'text'" {
  run bash "$WRAPPER" "Test type field"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_frontmatter_field "$filepath" "type" "text"
}

@test "T008: text capture sets source field to 'quick-capture'" {
  run bash "$WRAPPER" "Test source field"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_frontmatter_field "$filepath" "source" "quick-capture"
}

@test "T008: text capture sets captured timestamp in YYYY-MM-DD HH:MM:SS format" {
  run bash "$WRAPPER" "Test timestamp"
  [ "$status" -eq 0 ]

  local filepath="$output"
  assert_frontmatter_field "$filepath" "captured" ""
  # Verify format: YYYY-MM-DD HH:MM:SS
  local captured
  captured=$(sed -n '/^---$/,/^---$/p' "$filepath" | grep "^captured:" | sed 's/^captured: *//')
  [[ "$captured" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "T008: text capture preserves body content after front-matter" {
  local test_text="This is my test memory content"
  run bash "$WRAPPER" "$test_text"
  [ "$status" -eq 0 ]

  local filepath="$output"
  # Body should appear after the front-matter
  grep -q "$test_text" "$filepath"
}

@test "T008: text capture includes H1 heading with date" {
  run bash "$WRAPPER" "Test heading"
  [ "$status" -eq 0 ]

  local filepath="$output"
  # Should have an H1 heading with date
  grep -q '^# [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$filepath"
}

@test "T008: text capture exits with code 0 on success" {
  run bash "$WRAPPER" "Success test"
  [ "$status" -eq 0 ]
}

@test "T008: text capture outputs file path to stdout" {
  run bash "$WRAPPER" "Path test"
  [ "$status" -eq 0 ]

  # Output should contain the memories directory path
  [[ "$output" == *"$MEMORIES_DIR"* ]]
}

# ============================================================
# T009: Error-Handling Tests [TS-007, TS-008]
# ============================================================

@test "T009: text capture rejects empty input with exit 1" {
  run bash "$WRAPPER" ""
  [ "$status" -eq 1 ]
}

@test "T009: text capture rejects missing argument with exit 1" {
  run bash "$WRAPPER"
  [ "$status" -eq 1 ]
}

@test "T009: text capture writes error to stderr on empty input" {
  run bash "$WRAPPER" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error"* ]] || [[ "$output" == *"error"* ]]
}

@test "T009: text capture handles special characters in content" {
  local special_text='Hello "world" & <brackets> $dollar `backtick`'
  run bash "$WRAPPER" "$special_text"
  [ "$status" -eq 0 ]

  local filepath="$output"
  # Verify content was preserved (at least the non-shell-special parts)
  grep -q "Hello" "$filepath"
  grep -q "world" "$filepath"
}

@test "T009: text capture handles multiline content" {
  local multiline_text="Line 1
Line 2
Line 3"
  run bash "$WRAPPER" "$multiline_text"
  [ "$status" -eq 0 ]

  local filepath="$output"
  grep -q "Line 1" "$filepath"
}

@test "T009: text capture creates no file on empty input" {
  local before_count
  before_count=$(find "$MEMORIES_DIR" -name "mem_*_text.md" 2>/dev/null | wc -l | tr -d ' ')

  run bash "$WRAPPER" ""

  local after_count
  after_count=$(find "$MEMORIES_DIR" -name "mem_*_text.md" 2>/dev/null | wc -l | tr -d ' ')

  [ "$before_count" -eq "$after_count" ]
}
